pipeline {
    agent any
    
    environment {
        AWS_REGION = "us-east-1"
        ECR_REPO_NAME = "sample-app"
        DOCKER_TAG = "latest"
        EKS_CLUSTER_NAME = "main-eks-cluster"
        HELM_RELEASE_NAME = "sample-app"
        HELM_CHART_PATH = "./helm/sample-app"
        APP_DIR = "./app"
        TERRAFORM_DIR = "./main.tf"
    }
    
    stages {
        stage('Checkout Code') {
            steps {
                echo "Checking out code from Git repository..."
                checkout scm
            }
        }
        
        stage('Terraform Plan') {
            steps {
                echo "Running Terraform plan..."
                dir("${TERRAFORM_DIR}") {
                    sh '''
                        terraform init
                        terraform plan -out=tfplan
                    '''
                }
            }
        }
        
        stage('Terraform Apply') {
            steps {
                echo "Applying Terraform configuration..."
                dir("${TERRAFORM_DIR}") {
                    sh '''
                        terraform apply -auto-approve tfplan
                        terraform output
                    '''
                }
            }
        }
        
        stage('Docker Login to ECR') {
            steps {
                echo "Logging into AWS ECR..."
                withCredentials([
                    string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID'),
                    [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']
                ]) {
                    sh '''
                        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    '''
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo "Building Docker image..."
                withCredentials([string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID')]) {
                    dir("${APP_DIR}") {
                        sh '''
                            ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                            docker build -t ${ECR_REGISTRY}/${ECR_REPO_NAME}:${DOCKER_TAG} .
                            docker image ls | grep sample-app
                        '''
                    }
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                echo "Pushing Docker image to AWS ECR..."
                withCredentials([string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID')]) {
                    sh '''
                        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                        docker push ${ECR_REGISTRY}/${ECR_REPO_NAME}:${DOCKER_TAG}
                        echo "Image pushed: ${ECR_REGISTRY}/${ECR_REPO_NAME}:${DOCKER_TAG}"
                    '''
                }
            }
        }
        
        stage('Configure kubectl') {
            steps {
                echo "Configuring kubectl for EKS cluster..."
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh '''
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}
                        kubectl config current-context
                    '''
                }
            }
        }
        
        stage('Deploy with Helm') {
            steps {
                echo "Deploying application with Helm..."
                withCredentials([string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID')]) {
                    sh '''
                        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                        helm repo update
                        helm upgrade --install ${HELM_RELEASE_NAME} ${HELM_CHART_PATH} \
                            --values ${HELM_CHART_PATH}/values.yaml \
                            --set image.repository=${ECR_REGISTRY}/${ECR_REPO_NAME} \
                            --set image.tag=${DOCKER_TAG} \
                            --wait \
                            --timeout 5m
                    '''
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo "Verifying deployment..."
                sh '''
                    echo "Pod Status:"
                    kubectl get pods -n default | grep sample-app
                    
                    echo "Service Status:"
                    kubectl get svc -n default | grep sample-app
                    
                    echo "Helm Release Status:"
                    helm status ${HELM_RELEASE_NAME}
                '''
            }
        }
    }
    
    post {
        success {
            echo "Pipeline completed successfully!"
            echo "Application deployed to EKS cluster."
            echo "Helm release: ${HELM_RELEASE_NAME}"
        }
        failure {
            echo "Pipeline failed! Check logs above for details."
        }
        always {
            echo "Pipeline execution finished."
        }
    }
}
