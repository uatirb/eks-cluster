pipeline {
    agent {
        kubernetes {
            label 'docker-agent'
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: docker
      image: docker:20.10.24-dind
      securityContext:
        privileged: true
      volumeMounts:
        - name: docker-graph-storage
          mountPath: /var/lib/docker
      command:
        - /bin/sh
        - -c
        - /usr/local/bin/dockerd-entrypoint.sh
    - name: kubectl
      image: ubuntu:20.04
      securityContext:
        runAsUser: 0  # Run as root user to avoid permission issues
      command:
        - cat
      tty: true
  volumes:
    - name: docker-graph-storage
      emptyDir: {}
"""
        }
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // Step to check Docker version
        stage("Check Docker Version") {
            steps {
                script {
                    container('docker') {
                        // Display Docker version inside the Docker container
                        sh "docker build -t 908027419216.dkr.ecr.us-west-2.amazonaws.com/eks-repository:v${IMAGE_TAG} ."
                    }
                }
            }
        }

        // Login to AWS ECR and Push Image
        stage('Login to AWS ECR and Push Image') {
            steps {
                script {
                    container('docker') {
                        // Install AWS CLI
                        sh '''
                            apt-get update && apt-get install -y unzip curl
                            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                            unzip awscliv2.zip
                            sudo ./aws/install
                        '''
                        // Log in to AWS ECR
                        sh '''
                            aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 908027419216.dkr.ecr.us-west-2.amazonaws.com
                        '''
                        // Push the image to ECR
                        sh '''
                            docker push 908027419216.dkr.ecr.us-west-2.amazonaws.com/eks-repository:v${IMAGE_TAG}
                        '''
                    }
                }
            }
        }

        // Update Deployment YAML with the new image tag
        stage('Update Deployment YAML') {
            steps {
                script {
                    container('docker') {
                        // Replace the old image tag with the new one in the deployment YAML
                        sh "sed -i 's|image: 908027419216.dkr.ecr.us-west-2.amazonaws.com/eks-repository:v.*|image: 908027419216.dkr.ecr.us-west-2.amazonaws.com/eks-repository:v${IMAGE_TAG}|' ${YAML_FILE}"
                    }
                }
            }
        }

        // Stage for installing kubectl
        stage('Install kubectl') {
            steps {
                script {
                    container('kubectl') {
                        // Install kubectl manually using wget and curl in the kubectl container
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

        // Stage for deploying to Kubernetes
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    container('kubectl') {
                        // Assuming you have Kubernetes credentials setup
                        withKubeCredentials(kubectlCredentials: [[caCertificate: '', clusterName: 'k8-cluster', contextName: '', credentialsId: 'eks-secret', namespace: 'default', serverUrl: 'https://60CE00358BEF09B73D2F131A71EEB49A.gr7.us-west-2.eks.amazonaws.com']]) {
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
                // Clean up the workspace after execution
                echo "Cleaning up workspace..."
                cleanWs()
            }
        }
    }
}

