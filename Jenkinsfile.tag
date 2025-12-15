pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timestamps()
    }

    parameters {
        string(name: 'TAG_NAME', defaultValue: 'v1.0.0', description: 'Docker image tag')
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                bat 'npm ci --prefer-offline'
            }
        }

        stage('Build Application') {
            steps {
                bat 'npm run build'
                echo "Build completed for tag ${params.TAG_NAME}"
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    def imageName = "react:${params.TAG_NAME}"
                    bat "docker build -t ${imageName} ."
                }
            }
        }

        stage('Run Docker Container') {
            steps {
                script {
                    def tag = params.TAG_NAME
                    def imageName = "react:${tag}"
                    def containerName = "react_${tag.replace('.', '_')}"

                    bat "docker rm -f ${containerName} 2>nul || exit 0"
                    bat "docker run -d -p 8082:80 --name ${containerName} ${imageName}"

                    echo "Container ${containerName} running on http://localhost:8082"
                }
            }
        }

        stage('Smoke Test') {
            steps {
                bat 'call smoke\\smoke-test.bat'
                archiveArtifacts artifacts: 'smoke.log', allowEmptyArchive: false
            }
        }

        stage('Cleanup') {
            steps {
                script {
                    def containerName = "react_${params.TAG_NAME.replace('.', '_')}"
                    bat "docker stop ${containerName} 2>nul || exit 0"
                    bat "docker rm ${containerName} 2>nul || exit 0"
                    echo "Cleanup done for ${containerName}"
                }
            }
        }
    }

    post {
        success {
            echo "✔ BUILD SUCCESS for ${params.TAG_NAME}"
            echo "✔ App available on http://localhost:8082"
        }
        failure {
            echo "✖ BUILD FAILED for ${params.TAG_NAME}"
        }
    }
}
