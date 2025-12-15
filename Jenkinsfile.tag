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
            }
        }
        
        stage('Create Smoke Test') {
            steps {
                bat '''
                    @echo off > smoke-test.bat
                    echo set URL=http://localhost:8082 >> smoke-test.bat
                    echo set MAX_RETRIES=10 >> smoke-test.bat
                    echo echo Testing %%URL%% ... >> smoke-test.bat
                    echo for /l %%%%i in (1,1,%%MAX_RETRIES%%) do ( >> smoke-test.bat
                    echo     powershell -Command "try {$response = Invoke-WebRequest -Uri '%%URL%%' -UseBasicParsing -TimeoutSec 5; if ($response.StatusCode -eq 200) {exit 0} else {exit 1}} catch {exit 1}" ^> nul 2^>^&1 >> smoke-test.bat
                    echo     if !errorlevel! equ 0 ( >> smoke-test.bat
                    echo         echo SMOKE PASSED ^> smoke.log >> smoke-test.bat
                    echo         exit /b 0 >> smoke-test.bat
                    echo     ) >> smoke-test.bat
                    echo     if %%%%i lss %%MAX_RETRIES%% ( >> smoke-test.bat
                    echo         echo Waiting for application... Attempt %%%%i of %%MAX_RETRIES%% >> smoke-test.bat
                    echo         ping -n 2 127.0.0.1 ^> nul >> smoke-test.bat
                    echo     ) >> smoke-test.bat
                    echo ) >> smoke-test.bat
                    echo echo SMOKE FAILED ^> smoke.log >> smoke-test.bat
                    echo exit /b 1 >> smoke-test.bat
                '''
            }
        }
        
        stage('Run Docker') {
            steps {
                script {
                    def tag = env.TAG_NAME ?: env.GIT_COMMIT.take(7)
                    def imageName = "react:${tag}"
                    def containerName = "react_tag_${tag}"
                    
                    bat "docker rm -f ${containerName} 2>nul || exit 0"
                    bat "docker rmi ${imageName} 2>nul || exit 0"
                    
                    bat "docker build --no-cache -t ${imageName} ."
                    bat "docker run -d -p ${APP_PORT}:80 --name ${containerName} ${imageName}"
                    
                    bat "ping -n 6 127.0.0.1 > nul"
                }
            }
        }
        
        stage('Smoke Test') {
            steps {
                bat 'call smoke-test.bat'
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
                    def containerName = "react_tag_${tag}"
                    
                    bat "docker stop ${containerName} 2>nul || exit 0"
                    bat "docker rm ${containerName} 2>nul || exit 0"
                }
            }
        }
    }
    
    post {
        success {
            echo "Build succeeded"
        }
        failure {
            echo "Build failed"
        }
    }
}
EOF