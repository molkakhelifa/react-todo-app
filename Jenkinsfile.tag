pipeline {
    agent any
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
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
                    
                    // Port cleanup
                    bat """
                        @echo off
                        echo Cleaning port 8080 for tag build...
                        for /f "tokens=*" %%i in ('docker ps --format "{{.Names}}"') do (
                            docker port %%i | findstr ":8080" >nul
                            if !errorlevel! == 0 (
                                docker stop %%i 2>nul
                                docker rm %%i 2>nul
                            )
                        )
                        exit 0
                    """
                    
                    bat "docker rm -f ${containerName} 2>nul || exit 0"
                    bat "docker rmi ${imageName} 2>nul || exit 0"
                    
                    // Build and run
                    bat "docker build --no-cache -t ${imageName} ."
                    bat "docker run -d -p 8080:80 --name ${containerName} ${imageName}"
                    
                    // Wait for container to be ready using ping with retry logic
                    bat """
                        @echo off
                        setlocal enabledelayedexpansion
                        echo Waiting for container to be ready...
                        set max_retries=30
                        set retry_delay=2
                        set retry_count=0
                        
                        :retry_loop
                        ping -n 1 -w 1000 127.0.0.1 >nul
                        timeout /t 1 /nobreak >nul
                        set /a retry_count+=1
                        
                        echo Attempt !retry_count! of !max_retries!: Checking if application is up...
                        
                        curl -s -o nul -w "%%{http_code}" http://localhost:8080 | findstr "^200$" >nul
                        if !errorlevel! == 0 (
                            echo Application is ready!
                            exit 0
                        )
                        
                        if !retry_count! geq !max_retries! (
                            echo Application failed to start after !max_retries! attempts
                            exit 1
                        )
                        
                        timeout /t !retry_delay! /nobreak >nul
                        goto retry_loop
                    """
                    
                    echo "✓ Release ${tag} accessible at http://localhost:8080"
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
                    def containerName = "react_tag_${tag.replace('.', '_')}"
                    
                    bat "docker stop ${containerName} 2>nul || exit 0"
                    bat "docker rm ${containerName} 2>nul || exit 0"
                    
                    // DO NOT delete tagged image - it's a release!
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
        }
        failure {
            echo "✗ Build for tag ${env.TAG_NAME} failed"
            echo "✗ Release blocked - fix issues and create new tag"
        }
    }
}