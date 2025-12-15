# D'abord, sauvegardez l'ancien
cp Jenkinsfile.tag Jenkinsfile.tag.backup

# Créez un nouveau Jenkinsfile.tag COMPLET
cat > Jenkinsfile.tag << 'EOF'
pipeline {
    agent any
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
    }
    
    environment {
        APP_PORT = '8082'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Setup') {
            steps {
                bat 'npm ci --prefer-offline'
            }
        }
        
        stage('Build') {
            steps {
                bat 'npm run build'
                echo "✓ Building version: ${env.TAG_NAME}"
            }
        }
        
        stage('Run Docker') {
            steps {
                script {
                    def tag = env.TAG_NAME ?: env.GIT_COMMIT.take(7)
                    def imageName = "react:${tag}"
                    def containerName = "react_tag_${tag.replace('.', '_')}"
                    
                    bat """
                        @echo off
                        echo Cleaning port ${APP_PORT} for tag build...
                        for /f "tokens=*" %%i in ('docker ps --format "{{.Names}}"') do (
                            docker port %%i | findstr ":${APP_PORT}" >nul
                            if !errorlevel! == 0 (
                                docker stop %%i 2>nul
                                docker rm %%i 2>nul
                            )
                        )
                        exit 0
                    """
                    
                    bat "docker rm -f ${containerName} 2>nul || exit 0"
                    bat "docker rmi ${imageName} 2>nul || exit 0"
                    
                    bat "docker build --no-cache -t ${imageName} ."
                    bat "docker run -d -p ${APP_PORT}:80 --name ${containerName} ${imageName}"
                    bat "ping 127.0.0.1 -n 6 > nul"
                    
                    echo "✓ Release ${tag} accessible at http://localhost:${APP_PORT}"
                    echo "✓ Jenkins is at http://localhost:8081"
                }
            }
        }
        
        stage('Smoke Test') {
            steps {
                bat 'call smoke\\smoke-test.bat'
                archiveArtifacts artifacts: 'smoke.log', allowEmptyArchive: true
            }
        }
        
        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: 'dist/**,build.log,smoke.log', allowEmptyArchive: false
            }
        }
        
        stage('Cleanup') {
            steps {
                script {
                    def tag = env.TAG_NAME ?: env.GIT_COMMIT.take(7)
                    def containerName = "react_tag_${tag.replace('.', '_')}"
                    
                    bat "docker stop ${containerName} 2>nul || exit 0"
                    bat "docker rm ${containerName} 2>nul || exit 0"
                    
                    echo "✓ Tagged image react:${tag} preserved for deployment"
                    echo "✓ This is a release image - not automatically deleted"
                }
            }
        }
    }
    
    post {
        success {
            echo "✓ Build for tag ${env.TAG_NAME} succeeded"
            echo "✓ Release artifacts archived"
            echo "✓ Image react:${env.TAG_NAME} available for deployment"
            echo "✓ Application available at http://localhost:${APP_PORT}"
        }
        failure {
            echo "✗ Build for tag ${env.TAG_NAME} failed"
            echo "✗ Release blocked - fix issues and create new tag"
        }
    }
}
EOF