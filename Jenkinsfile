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
        stage("Push Images") {
            steps {
                script {
                    container('docker') {
                        // Use Jenkins credentials to access AWS
                        withCredentials([[ 
                            $class: 'AmazonWebServicesCredentialsBinding', 
                            credentialsId: 'aws-credentials-id'  // Replace with your AWS credentials ID
                        ]]) {
                            
                            // Push the image to ECR
                            sh '''
                                docker push 908027419216.dkr.ecr.us-west-2.amazonaws.com/eks-repository:v${IMAGE_TAG}
                            '''
                        }
                    }
                }
            }
        }

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
		stage('Install kubectl') {
            steps {
                script {
                    container('kubectl') {
                        // Install kubectl using wget (bypassing apk/curl issues)
                        sh '''
                            # Update package list
                            apt-get update
                            
                            # Install curl and other dependencies
                            apt-get install -y curl 
                            

                            # Install kubectl
                            curl -LO "https://dl.k8s.io/release/v1.26.0/bin/linux/amd64/kubectl" 
							
                            # Make kubectl executable
                            chmod +x kubectl
                            
                            # Move kubectl to /usr/local/bin/ (requires root privileges)
                            mv kubectl /usr/local/bin/kubectl
                            
                            # Verify kubectl installation
                            kubectl version --client
                        '''
                    }
                }
            }
        }
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
                echo "Cleaning up workspace..."
                cleanWs()
            }
        }
    }
}
