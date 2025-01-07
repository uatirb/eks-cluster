pipeline {
    agent {
        kubernetes {
            label 'docker-agent'
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: jenkins-pipeline
spec:
  containers:
    - name: docker
      image: docker:20.10.24-dind
      securityContext:
        privileged: true  # Required for Docker-in-Docker
      volumeMounts:
        - name: docker-sock
          mountPath: /var/run/docker.sock  # Correct mount path for Docker socket
      command:
        - /bin/sh
        - -c
        - /usr/local/bin/dockerd-entrypoint.sh  # Starts Docker daemon
    - name: kubectl
      image: ubuntu:20.04
      securityContext:
        runAsUser: 0  # Run as root user
      command:
        - cat
      tty: true
    - name: aws-cli
      image: amazon/aws-cli:2.13.1
      command:
        - cat
      tty: true
  volumes:
    - name: docker-sock
      hostPath:
        path: /var/run/docker.sock  # Ensure the socket is mounted from the host
"""
        }
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage("Build Images") {
            steps {
                script {
                    container('docker') {
                        // Build Docker image inside the Docker container
                        sh "docker build -t 908027419216.dkr.ecr.us-west-2.amazonaws.com/eks-repository:v${IMAGE_TAG} ."
                    }
                }
            }
        }
        stage('Login to AWS ECR') {
            steps {
                container('aws-cli') {
                    echo "Logging in to AWS ECR"
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding', 
                        credentialsId: 'aws-credentials-id'  // Replace with your AWS credentials ID
                    ]]) {
                        sh '''
                            aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 908027419216.dkr.ecr.us-west-2.amazonaws.com
                        '''
                    }
                }
            }
        }
        stage("Push Images") {
            steps {
                script {
                    container('docker') {
                        // Push the image to ECR
                        sh '''
                            docker push 908027419216.dkr.ecr.us-west-2.amazonaws.com/eks-repository:v${IMAGE_TAG}
                        '''
                    }
                }
            }
        }

        stage('Update Deployment YAML') {
            steps {
                script {
                    container('kubectl') {
                        // Replace the old image tag with the new one in the deployment YAML
                        sh "sed -i 's|image: 908027419216.dkr.ecr.us-west-2.amazonaws.com/eks-repository:v.*|image: 908027419216.dkr.ecr.us-west-2.amazonaws.com/eks-repository:v${IMAGE_TAG}|' ${YAML_FILE}"
                    }
                }
            }
        }
        stage('Install kubectl') {
            steps {
                script {
                    container('kubectl') {
                        // Install kubectl using apt (Ubuntu-based containers)
                        sh '''
                            apt-get update
                            apt-get install -y curl
                            curl -LO "https://dl.k8s.io/release/v1.26.0/bin/linux/amd64/kubectl"
                            chmod +x kubectl
                            mv kubectl /usr/local/bin/kubectl
                            kubectl version --client
                        '''
                    }
                }
            }
        }
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    container('kubectl') {
                        withKubeCredentials(kubectlCredentials: [[
                            caCertificate: '', 
                            clusterName: 'k8-cluster', 
                            contextName: '', 
                            credentialsId: 'eks-secret', 
                            namespace: 'default', 
                            serverUrl: 'https://60CE00358BEF09B73D2F131A71EEB49A.gr7.us-west-2.eks.amazonaws.com'
                        ]]) {
                            sh 'kubectl apply -f ${YAML_FILE} --namespace ${NAMESPACE}'
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            script {
                echo "Cleaning up workspace..."
                cleanWs()
            }
        }
    }
}
