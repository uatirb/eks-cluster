pipeline {
    agent {
        kubernetes {
            label 'docker-agent'
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: ubuntu
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

    environment {
        AWS_DEFAULT_REGION = 'us-west-2'  // Replace with your AWS region
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // Step to Install Docker, AWS CLI, and kubectl
        stage('Install Docker, AWS CLI, and kubectl') {
            steps {
                script {
                    container('ubuntu') {
                        // Install Docker
                        sh '''
                            apt-get update
                            apt-get install curl unzip -y
                            apt-get install -y docker.io
                        '''

                        // Install AWS CLI
                        sh '''
                            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                            unzip awscliv2.zip
                            sudo ./aws/install
                            aws --version
                        '''

                        // Install kubectl
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

        // Step to check Docker version
        stage("Check Docker Version") {
            steps {
                script {
                    container('ubuntu') {
                        // Display Docker version inside the Ubuntu container
                        sh "docker build -t 908027419216.dkr.ecr.us-west-2.amazonaws.com/eks-repository:v${IMAGE_TAG} ."
                    }
                }
            }
        }

        // Login to AWS ECR and Push Image
        stage('Login to AWS ECR and Push Image') {
            steps {
                script {
                    container('ubuntu') {
                        // Use Jenkins credentials to access AWS
                        withCredentials([[
                            $class: 'AmazonWebServicesCredentialsBinding', 
                            credentialsId: 'aws-credentials-id'  // Replace with your AWS credentials ID
                        ]]) {
                            // Log in to AWS ECR
                            sh '''
                                aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin 908027419216.dkr.ecr.us-west-2.amazonaws.com
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

        // Stage for deploying to Kubernetes
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    container('ubuntu') {
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
