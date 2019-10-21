pipeline {

    agent {
        // label "" also could have been 'agent any' - that has the same meaning.
        label "master"
    }

    environment {
        // GLobal Vars
        PIPELINES_NAMESPACE = "mod-ci-cd"
        APP_NAME = "dotnet-todo"

        JENKINS_TAG = "${JOB_NAME}.${BUILD_NUMBER}".replace("/", "-")
        JOB_NAME = "${JOB_NAME}".replace("/", "-")

        GIT_SSL_NO_VERIFY = true
        GIT_CREDENTIALS = credentials('mod-ci-cd-jenkins-git-password')
        NEXUS_CREDS = credentials('mod-ci-cd-nexus-password')

        GITLAB_DOMAIN = ""
        GITLAB_PROJECT = ""
        // SONAR_SCANNER_HOME = tool "sonar-scanner-tool"
    }

    // The options directive is for configuration that applies to the whole job.
    options {
        buildDiscarder(logRotator(numToKeepStr: '50', artifactNumToKeepStr: '1'))
        timeout(time: 15, unit: 'MINUTES')
        ansiColor('xterm')
        timestamps()
    }

    stages {
        stage("prepare environment for master deploy") {
            agent {
                node {
                    label "master"
                }
            }
            when {
              expression { GIT_BRANCH ==~ /(.*master)/ }
            }
            steps {
                script {
                    // Arbitrary Groovy Script executions can do in script tags
                    env.PROJECT_NAMESPACE = "mod-test"
                    env.NODE_ENV = "test"
                    env.E2E_TEST_ROUTE = "oc get route/${APP_NAME} --template='{{.spec.host}}' -n ${PROJECT_NAMESPACE}".execute().text.minus("'").minus("'")
                }
                
                echo '### Add cluster configs ###'
                sh '''
                    oc process -f .openshift/buildconfig.yml NAME=${APP_NAME} BUILD_TAG=latest | oc apply -n ${PIPELINES_NAMESPACE} -f - 
                    oc process -f .openshift/deploymentconfig.yml NAME=${APP_NAME} APP_TAG=latest DEPLOYER_USER=jenkins PIPELINES_NAMESPACE=${PIPELINES_NAMESPACE} NAMESPACE=${PROJECT_NAMESPACE} | oc apply -n ${PROJECT_NAMESPACE} -f - 
                '''
            }
        }
        stage("prepare environment for develop deploy") {
            agent {
                node {
                    label "master"
                }
            }
            when {
              expression { GIT_BRANCH ==~ /(.*develop)/ }
            }
            steps {
                script {
                    // Arbitrary Groovy Script executions can do in script tags
                    env.PROJECT_NAMESPACE = "mod-dev"
                    env.NODE_ENV = "dev"
                    env.E2E_TEST_ROUTE = "oc get route/${APP_NAME} --template='{{.spec.host}}' -n ${PROJECT_NAMESPACE}".execute().text.minus("'").minus("'")
                }
                
                echo '### Add cluster configs ###'
                sh '''
                    oc process -f .openshift/buildconfig.yml NAME=${APP_NAME} BUILD_TAG=latest | oc apply -n ${PIPELINES_NAMESPACE} -f - 
                    oc process -f .openshift/deploymentconfig.yml NAME=${APP_NAME} APP_TAG=latest DEPLOYER_USER=jenkins PIPELINES_NAMESPACE=${PIPELINES_NAMESPACE} NAMESPACE=${PROJECT_NAMESPACE} | oc apply -n ${PROJECT_NAMESPACE} -f - 
                '''
            }
        }

        stage("dotnet-build") {
            agent {
                node {
                    label "jenkins-slave-dotnet"
                }
            }
            steps {
                sh 'printenv'

                echo '### Install deps ###'

                echo '### Running build ###'
                sh 'dotnet publish -c Release /p:MicrosoftNETPlatformLibrary=Microsoft.NETCore.App'

                echo '### Packaging App for Nexus ###'
                sh 'mkdir -p package-contents && cp -vr bin Dockerfile package-contents && zip -r package-contents.zip package-contents'
                sh 'curl -vvv -u ${NEXUS_CREDS} --upload-file package-contents.zip http://${NEXUS_SERVICE_HOST}:${NEXUS_SERVICE_PORT}/repository/labs-static/com/redhat/fe/${JOB_NAME}.${BUILD_NUMBER}/package-contents.zip'
            }
            // Post can be used both on individual stages and for the entire build.
            post {
                always {
                    echo "something like add tests"
                    // Notify slack or some such
                }
                success {
                    echo "Git tagging"
                    sh'''
                        git config --global user.email "jenkins@example.com"
                        git config --global user.name "jenkins-ci"
                        git tag -a ${JENKINS_TAG} -m "JENKINS automated commit"
                        # git push https://${GIT_CREDENTIALS_USR}:${GIT_CREDENTIALS_PSW}@${GITLAB_DOMAIN}/${GITLAB_PROJECT}/${APP_NAME}.git --tags
                    '''
                }
            }
        }

        stage("dotnet-bake") {
            agent {
                node {
                    label "master"
                }
            }
            when {
                expression { GIT_BRANCH ==~ /(.*master|.*develop)/ }
            }
            steps {
                echo '### Get Binary from Nexus ###'
                sh  '''
                        rm -rf package-contents*
                        curl -v -f http://${NEXUS_CREDS}@${NEXUS_SERVICE_HOST}:${NEXUS_SERVICE_PORT}/repository/labs-static/com/redhat/fe/${JENKINS_TAG}/package-contents.zip -o package-contents.zip
                        unzip package-contents.zip
                    '''
                echo '### Create Linux Container Image from package ###'
                sh  '''
                        oc project ${PIPELINES_NAMESPACE} # probs not needed
                        oc patch bc ${APP_NAME} -p "{\\"spec\\":{\\"output\\":{\\"to\\":{\\"kind\\":\\"ImageStreamTag\\",\\"name\\":\\"${APP_NAME}:latest\\"}}}}"
                        oc start-build ${APP_NAME} --from-dir=package-contents/ --follow
                    '''
            }
        }

        stage("dotnet-deploy") {
            agent {
                node {
                    label "master"
                }
            }
            when {
                expression { GIT_BRANCH ==~ /(.*master|.*develop)/ }
            }
            steps {
                echo '### tag image for namespace ###'
                sh  '''
                    oc project ${PROJECT_NAMESPACE}
                    oc tag ${PIPELINES_NAMESPACE}/${APP_NAME}:latest ${PROJECT_NAMESPACE}/${APP_NAME}:latest
                    '''
                echo '### set env vars and image for deployment ###'
                sh '''
                    oc set image dc/${APP_NAME} ${APP_NAME}=docker-registry.default.svc:5000/${PROJECT_NAMESPACE}/${APP_NAME}:latest
                    oc rollout latest dc/${APP_NAME}
                '''
                echo '### Verify OCP Deployment ###'
                openshiftVerifyDeployment depCfg: env.APP_NAME,
                    namespace: env.PROJECT_NAMESPACE,
                    replicaCount: '1',
                    verbose: 'false',
                    verifyReplicaCount: 'true',
                    waitTime: '',
                    waitUnit: 'sec'
            }
        }
    }
    post {
        always {
            archiveArtifacts "**"
        }
    }
}
