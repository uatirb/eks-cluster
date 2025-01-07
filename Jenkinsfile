pipeline {
    agent {
        kubernetes {
            label 'docker-agent'
            yaml """
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
    - name: docker
      image: docker:20.10.7
      securityContext:
        runAsUser: 0  # Run as root user to avoid permission issues with Docker
      command:
        - cat
      tty: true
      volumeMounts:
        - mountPath: /var/run/docker.sock
          name: docker-socket

    - name: ubuntu
      image: ubuntu:20.04
      securityContext:
        runAsUser: 0  # Run as root user
      command:
        - cat
      tty: true
  volumes:
    - name: docker-socket
      hostPath:
        path: /var/run/docker.sock
        type: Socket
"""
        }
    }

    environment {
        AWS_DEFAULT_REGION = 'us-west-2'
        
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // Install Docker, AWS CLI, and kubectl
        stage('Install Docker, AWS CLI, and kubectl') {
            steps {
                script {
                    container('ubuntu') {
                        // Install AWS CLI and kubectl
                        sh '''
                            
                            curl -LO https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl
                            chmod +x kubectl
                            sudo mv kubectl /usr/local/bin/
                            kubectl version --client
                        '''
                    }
                }
            }
        }

        // Build Docker Image in Docker Container
        stage('Build Docker Image') {
            steps {
                script {
                    container('docker') {
                        // Build Docker image inside the Docker container
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
                        // Use Jenkins credentials to access AWS
                        withCredentials([[ 
                            $class: 'AmazonWebServicesCredentialsBinding', 
                            credentialsId: 'aws-credentials-id'  // Replace with your AWS credentials ID
                        ]]) {
                            // Log in to AWS ECR
                            sh '''
							    apt-get install curl -y
							    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                                unzip awscliv2.zip
                                ./aws/install
                                aws --version
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
        }

        // Update Deployment YAML with the new image tag
        stage('Update Deployment YAML') {
            steps {
                script {
                    container('ubuntu') {
                        // Replace the old image tag with the new one in the deployment YAML
                        sh "sed -i 's|image: 908027419216.dkr.ecr.us-west-2.amazonaws.com/eks-repository:v.*|image: 908027419216.dkr.ecr.us-west-2.amazonaws.com/eks-repository:v${IMAGE_TAG}|' ${YAML_FILE}"
                    }
                }
            }
        }

        // Deploy to Kubernetes
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    container('ubuntu') {
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
                // Clean up the workspace after execution
                echo "Cleaning up workspace..."
                cleanWs()
            }
        }
    }
}
