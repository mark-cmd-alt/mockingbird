FROM swift:5.10.1-rhel-ubi9
WORKDIR /mockingbird
COPY . .

# Set up
RUN yum install -y zip
RUN swift --version

# Build automation
# RUN Sources/MockingbirdAutomationCli/buildAndRun.sh
# RUN cp .build/debug/automation /usr/bin

# # Build generator
# RUN Sources/MockingbirdCli/buildAndRun.sh
# RUN cp .build/debug/mockingbird /usr/bin

RUN Sources/MockingbirdAutomationCli/buildAndRun.sh build cli --platform centos --archive .build/mockingbird/artifacts/Mockingbird-centos.zip

# ENTRYPOINT ["mockingbird"]
# CMD ["--help"]

# RUN tar -czf /build.tar.gz .build/debug/mockingbird
