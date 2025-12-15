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

    environment {
        IMAGE_NAME = "react:${TAG_NAME}"
        CONTAINER_NAME = "react_${TAG_NAME.replace('.', '_')}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                bat 'npm ci'
            }
        }

        stage('Build Application') {
            steps {
                bat 'npm run build'
                echo "Build completed for tag ${TAG_NAME}"
            }
        }

        stage('Build Docker Image') {
            steps {
                bat 'docker build -t %IMAGE_NAME% .'
            }
        }

        stage('Run Docker Container') {
            steps {
                bat """
                @echo off
                docker rm -f %CONTAINER_NAME% 2>nul

                docker run -d ^
                  -p 8082:80 ^
                  --name %CONTAINER_NAME% ^
                  %IMAGE_NAME%
                """
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
                bat """
                @echo off
                docker stop %CONTAINER_NAME% 2>nul
                docker rm %CONTAINER_NAME% 2>nul
                """
            }
        }
    }

    post {
        success {
            echo "✔ BUILD SUCCESS for ${TAG_NAME}"
            echo "✔ App available on http://localhost:8082"
        }
        failure {
            echo "✖ BUILD FAILED for ${TAG_NAME}"
        }
    }
}
