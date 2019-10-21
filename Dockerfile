# FROM registry.access.redhat.com/dotnet/dotnet-22-runtime-rhel7:2.2-17
FROM quay.io/rht-labs/dotnet-22-runtime-centos7:latest
ADD bin/Release/netcoreapp2.2/publish/. .
CMD [ "dotnet", "TodoApi.dll" ]