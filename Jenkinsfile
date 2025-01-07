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
        runAsUser: 0  # Run as root user to avoid permission issues
      volumeMounts:
        - name: docker-graph-storage
          mountPath: /var/lib/docker
      command:
        - /bin/bash
        - -c
        - |
          apt-get update && apt-get install -y \
          docker.io \
          curl \
          unzip \
          awscli \
          kubectl \
          && tail -f /dev/null  # Keep the container running
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
