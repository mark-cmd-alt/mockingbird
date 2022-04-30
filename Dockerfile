FROM swift:5.5.2-centos8
WORKDIR /mockingbird
COPY . .

# CentOS 8 EOL
RUN sed -i 's|mirrorlist|#mirrorlist|g' /etc/yum.repos.d/CentOS-*
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

# Set up
RUN yum install -y zip
RUN swift --version

# Build automation
RUN Sources/MockingbirdAutomationCli/buildAndRun.sh
RUN cp .build/debug/automation /usr/bin

# Build generator
RUN Sources/MockingbirdCli/buildAndRun.sh
RUN cp .build/debug/mockingbird /usr/bin

ENTRYPOINT ["mockingbird"]
CMD ["--help"]
