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
        runAsUser: 0  # Run as root user (to avoid permission issues)
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

        stage('Login to AWS ECR') {
            steps {
                container('kubectl') {
                    // Correct usage of withCredentials
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding', 
                        credentialsId: 'aws-credentials-id'  // Replace with your AWS credentials ID
                    ]]) {
                      

                        // Install kubectl
                        sh '''
                            apt-get update && apt-get install curl -y
                            curl -LO https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl
                            chmod +x kubectl
                            mv kubectl /usr/local/bin/
                            kubectl version --client
                        '''
                    }
                }
            }
        }



        stage("Push Images to ECR") {
            steps {
                container('docker') {
                    // Push the image to ECR
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding', 
                        credentialsId: 'aws-credentials-id'  // Replace with your AWS credentials ID
                    ]]) {
                        sh '''
                            # Install AWS CLI
                            apk update && apk add --no-cache curl unzip python3 py3-pip
                            pip install awscli
                        
                            aws --version
                        
                            aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 908027419216.dkr.ecr.us-west-2.amazonaws.com
                            docker build -t 908027419216.dkr.ecr.us-west-2.amazonaws.com/eks-repository:v${IMAGE_TAG} .
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

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    container('kubectl') {
                        withKubeCredentials(kubectlCredentials: [[ caCertificate: '', clusterName: 'k8-cluster', contextName: '', credentialsId: 'eks-secret', namespace: 'default', serverUrl: 'https://60CE00358BEF09B73D2F131A71EEB49A.gr7.us-west-2.eks.amazonaws.com'
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
