FROM quay.io/redhat-cop/tool-box:latest

USER root
RUN  curl -L https://mirror.openshift.com/pub/openshift-v4/clients/odo/v1.0.0/odo-linux-amd64 -o /usr/local/bin/odo

RUN chmod u+x /usr/local/bin/run  && \
    chmod u+x /usr/local/bin/odo
USER 1001