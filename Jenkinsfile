@Library('devsecops-shared-lib') _

pipeline {
    agent any

    options {
        timestamps()
        ansiColor('xterm')
        timeout(time: 45, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '30'))
        disableConcurrentBuilds()
    }

    parameters {
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region of the ECR registry')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Environment to deploy to')
    }

    environment {
        // Only keep static variables here that don't depend on files in the repository
        ECR_REGISTRY    = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com"
        IMAGE_TAG       = "${(env.GIT_COMMIT ?: '00000000').take(8)}-${env.BUILD_NUMBER}"
        SCAN_REPORT_DIR = "reports"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    // 1. Read git commit
                    env.GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()

                    // 2. NOW we read the config because the repo has been cloned!
                    def appConfig = readAppConfig()
                    env.APP_NAME  = appConfig.name
                    env.APP_TYPE  = appConfig.appType

                    // 3. Build the rest of our URLs dynamically
                    env.ECR_REPO  = "${env.ECR_REGISTRY}/${env.APP_NAME}"
                    env.IMAGE_REF = "${env.ECR_REPO}:${env.IMAGE_TAG}"

                    verifyCommitSignature(required: params.ENVIRONMENT == 'prod')
                }
            }
        }

        stage('Secrets Scan') {
            steps {
                scanForSecrets(tool: 'gitleaks', failOnFinding: true)
            }
        }

        stage('Static Analysis (SAST)') {
            parallel {
                stage('SonarQube') {
                    steps {
                        script {
                            def scannerHome = tool 'sonar-scanner'
                                 withSonarQubeEnv('sonarqube-prod') {
                                      sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=${env.APP_NAME} -Dsonar.sources=. -Dsonar.branch.name=${env.BRANCH_NAME}"
                                 }
                        }
                    }
                }
                stage('Quality Gate') {
                    steps {
                        timeout(time: 10, unit: 'MINUTES') {
                            waitForQualityGate abortPipeline: true
                        }
                    }
                }
            }
        }

        stage('Dependency Scan') {
            steps {
                dependencyScan(tool: 'trivy-fs', failOnSeverity: 'CRITICAL')
            }
        }

        stage('Build Artifact & Test') {
            steps {
                // Pass the appType we cached during checkout
                buildArtifact(appType: env.APP_TYPE)
                runTests()
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml, **/test-results/**/*.xml'
                }
            }
        }

        // =================================================================
        // BRANCH GATE: Artifact Creation & GitOps Handoff (Main branch only)
        // =================================================================

        stage('Build Container Image') {
            when { branch 'main' }
            steps {
                buildContainerImage(imageRef: env.IMAGE_REF, dockerfile: 'Dockerfile')
            }
        }

        stage('Container Image Scan') {
            when { branch 'main' }
            steps {
                scanImage(imageRef: env.IMAGE_REF, tool: 'trivy', failOnSeverity: 'CRITICAL', reportDir: env.SCAN_REPORT_DIR)
            }
            post {
                always {
                    archiveArtifacts artifacts: "${SCAN_REPORT_DIR}/**", allowEmptyArchive: true
                }
            }
        }

        stage('Push to ECR') {
            when { branch 'main' }
            steps {
                pushImage(imageRef: env.IMAGE_REF)
            }
        }

        stage('Sign & Attest Image') {
            when { branch 'main' }
            steps {
                signImage(imageRef: env.IMAGE_REF)
                generateSBOM(imageRef: env.IMAGE_REF, format: 'cyclonedx', outputDir: env.SCAN_REPORT_DIR)
            }
        }

        stage('Update GitOps Config') {
            when { branch 'main' }
            steps {
                updateGitOpsManifest(
                    appName: env.APP_NAME,
                    environment: params.ENVIRONMENT,
                    imageTag: env.IMAGE_TAG
                )
            }
        }
    }

    post {
        success {
            script {
                def msg = (env.BRANCH_NAME != 'main') ?
                    "${env.APP_NAME}: checks passed on branch ${env.BRANCH_NAME} (no image built)" :
                    "${env.APP_NAME}:${env.IMAGE_TAG} handed off to GitOps for ${params.ENVIRONMENT} deployment."
                notify(status: 'SUCCESS', message: msg)
            }
        }
        failure {
            notify(status: 'FAILURE', message: "Pipeline failed for ${env.APP_NAME}. See console log.")
        }
        always {
            cleanWs(deleteDirs: true, notFailBuild: true)
        }
    }
}