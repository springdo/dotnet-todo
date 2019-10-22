FROM fedora:latest

ENV OC_CLIENT_MIRROR https://mirror.openshift.com/pub/openshift-v3/clients/3.11.0-0.32.0/linux/oc.tar.gz
ENV HOME /home/tool-box

RUN dnf -y update && \
    INSTALL_PKGS="git tree vim unzip python-pip jq" && \
    dnf -y install $INSTALL_PKGS && \
    dnf clean all && \
    curl $OC_CLIENT_MIRROR | tar -C /usr/local/bin/ -xzf - && \
    mkdir -m 775 $HOME && \
    chmod 775 /etc/passwd

RUN pip install git+https://github.com/ansible/ansible.git@stable-2.8

RUN  curl -L https://mirror.openshift.com/pub/openshift-v4/clients/odo/latest/odo-darwin-amd64 -o /usr/local/bin/odo  && \
     chmod +x /usr/local/bin/odo

WORKDIR $HOME

ADD ./root /

RUN chmod u+x /usr/local/bin/run

USER 1001

ENTRYPOINT ["/usr/local/bin/run"]
CMD ["sleep", "infinity"]