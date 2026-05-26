pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = '938064475800'
        AWS_CREDENTIALS_ID = 'aws-credentials'
        ECR_REPO_NAME = 'sample-app'
        DOCKER_TAG = 'latest'
        EKS_CLUSTER_NAME = 'main-eks-cluster'
        HELM_RELEASE_NAME = 'sample-app'
        HELM_CHART_PATH = './helm/sample-app'
        APP_DIR = './app'
        TERRAFORM_DIR = './main.tf'
    }

    stages {
        stage('Checkout Code') {
            steps {
                echo 'Checking out code from Git repository...'
                checkout scm
            }
        }

        stage('Terraform Plan') {
            steps {
                echo 'Running Terraform plan...'
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: AWS_CREDENTIALS_ID]]) {
                    dir(TERRAFORM_DIR) {
                        timeout(time: 60, unit: 'MINUTES') {
                            sh '''
                                set -x
                                echo "AWS Region: ${AWS_REGION}"
                                echo "Terraform directory: $(pwd)"
                                terraform init -input=false
                                terraform plan -out=tfplan -input=false -lock=false
                            '''
                        }
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                echo 'Applying Terraform configuration...'
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: AWS_CREDENTIALS_ID]]) {
                    dir(TERRAFORM_DIR) {
                        timeout(time: 60, unit: 'MINUTES') {
                            sh '''
                                set -x
                                terraform apply -input=false -auto-approve -lock=false tfplan
                                terraform output
                            '''
                        }
                    }
                }
            }
        }

        stage('Login to ECR') {
            steps {
                echo 'Logging into AWS ECR...'
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: AWS_CREDENTIALS_ID]]) {
                    sh '''
                        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                        aws ecr create-repository --repository-name ${ECR_REPO_NAME} --region ${AWS_REGION} || true
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                echo 'Building Docker image...'
                dir(APP_DIR) {
                    sh '''
                        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                        docker build -t ${ECR_REGISTRY}/${ECR_REPO_NAME}:${DOCKER_TAG} .
                        docker image ls | grep sample-app || true
                    '''
                }
            }
        }

        stage('Push to ECR') {
            steps {
                echo 'Pushing Docker image to AWS ECR...'
                sh '''
                    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                    ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    docker push ${ECR_REGISTRY}/${ECR_REPO_NAME}:${DOCKER_TAG}
                    echo "Image pushed: ${ECR_REGISTRY}/${ECR_REPO_NAME}:${DOCKER_TAG}"
                '''
            }
        }

        stage('Configure kubectl') {
            steps {
                echo 'Configuring kubectl for EKS cluster...'
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: AWS_CREDENTIALS_ID]]) {
                    sh '''
                        export KUBECONFIG="$WORKSPACE/.kube/config"
                        mkdir -p "$(dirname "$KUBECONFIG")"
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME} --kubeconfig "$KUBECONFIG"
                        kubectl config current-context
                    '''
                }
            }
        }

        stage('Deploy with Helm') {
            steps {
                echo 'Deploying application with Helm...'
                sh '''
                    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                    ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    helm repo update
                    helm upgrade --install ${HELM_RELEASE_NAME} ${HELM_CHART_PATH} \
                        --values ${HELM_CHART_PATH}/values.yaml \
                        --set image.repository=${ECR_REGISTRY}/${ECR_REPO_NAME} \
                        --set image.tag=${DOCKER_TAG} \
                        --wait \
                        --timeout 10m
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                echo 'Verifying deployment...'
                sh '''
                    echo "Pod Status:"
                    kubectl get pods -n default | grep sample-app || true
                    echo "Service Status:"
                    kubectl get svc -n default | grep sample-app || true
                    echo "Helm Release Status:"
                    helm status ${HELM_RELEASE_NAME}
                '''
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
            echo "Application deployed to EKS cluster."
            echo "Helm release: ${HELM_RELEASE_NAME}"
        }
        failure {
            echo 'Pipeline failed! Check logs above for details.'
        }
        always {
            echo 'Pipeline execution finished.'
        }
    }
}
