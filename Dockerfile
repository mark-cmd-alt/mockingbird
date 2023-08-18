FROM swift:centos7
WORKDIR /mockingbird
COPY . .

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
