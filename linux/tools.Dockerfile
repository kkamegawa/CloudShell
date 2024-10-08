# IMAGE_LOCATION refers to a Microsoft-internal container registry which stores a cached version
# of the image built from base.Dockerfile. If you are building this file outside Microsoft, you
# won't be able to reach this location, but don't worry!

# To build yourself locally, override this location with a local image tag. See README.md for more detail

ARG IMAGE_LOCATION=cdpxb787066ec88f4e20ae65e42a858c42ca00.azurecr.io/official/cloudshell:base.master.11e65d27.20240822.1
# Copy from base build
FROM ${IMAGE_LOCATION}

ARG TARGETPLATFORM

# install latest azure-cli
LABEL org.opencontainers.image.source="https://github.com/kkamegawa/CloudShell"

RUN tdnf clean all && \
    tdnf repolist --refresh && \
    ACCEPT_EULA=Y tdnf update -y && \
    tdnf install azure-cli -y && \
    tdnf clean all && \
    rm -rf /var/cache/tdnf/*

# Install any Azure CLI extensions that should be included by default.
RUN az extension add --system --name ai-examples -y \
    && az extension add --system --name ssh -y \
    && az extension add --system --name ml -y

# Install kubectl
RUN az aks install-cli \
    && chmod +x /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubelogin

# Install vscode
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then wget -nv -O vscode.tar.gz "https://code.visualstudio.com/sha/download?build=insider&os=cli-alpine-x64" \
    && tar -xvzf vscode.tar.gz \
    && mv ./code-insiders /bin/vscode \
    && rm vscode.tar.gz ; fi

RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then wget -nv -O vscode.tar.gz "https://code.visualstudio.com/sha/download?build=insider&os=cli-alpine-arm64" \
    && tar -xvzf vscode.tar.gz \
    && mv ./code-insiders /bin/vscode \
    && rm vscode.tar.gz ; fi

# Install azure-developer-cli (azd)
ENV AZD_IN_CLOUDSHELL=1
ENV AZD_SKIP_UPDATE_CHECK=1
RUN curl -fsSL https://aka.ms/install-azd.sh | bash

RUN mkdir -p /usr/cloudshell
WORKDIR /usr/cloudshell

# Install Azure Static Web Apps CLI
RUN npm install -g @azure/static-web-apps-cli

# Install Bicep CLI
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64 \
  && chmod +x ./bicep \
  && mv ./bicep /usr/local/bin/bicep \
  && bicep --help; fi

RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-arm64 \
  && chmod +x ./bicep \
  && mv ./bicep /usr/local/bin/bicep \
  && bicep --help; fi

# Temp: fix ansible modules. Proper fix is to update base layer to use regular python for Ansible.
RUN mkdir -p /usr/share/ansible/collections/ansible_collections/azure/azcollection/ \
    && wget -nv -q -O /usr/share/ansible/collections/ansible_collections/azure/azcollection/requirements.txt https://raw.githubusercontent.com/ansible-collections/azure/dev/requirements.txt \
    && /opt/ansible/bin/python -m pip install -r /usr/share/ansible/collections/ansible_collections/azure/azcollection/requirements.txt

# Update pip
RUN /opt/ansible/bin/python -m pip install --upgrade pip

# Powershell telemetry
ENV POWERSHELL_DISTRIBUTION_CHANNEL=CloudShell \
    # don't tell users to upgrade, they can't
    POWERSHELL_UPDATECHECK=Off

# Copy and run script to Install powershell modules and setup Powershell machine profile
COPY ./linux/powershell/ powershell
RUN /usr/bin/pwsh -File ./powershell/setupPowerShell.ps1 -image Base && \
    cp -r ./powershell/PSCloudShellUtility /usr/local/share/powershell/Modules/PSCloudShellUtility/ && \
    /usr/bin/pwsh -File ./powershell/setupPowerShell.ps1 -image Top && \
    # Install Powershell warmup script
    mkdir -p linux/powershell && \
    cp powershell/Invoke-PreparePowerShell.ps1 linux/powershell/Invoke-PreparePowerShell.ps1 && \
    rm -rf ./powershell

# Remove su so users don't have su access by default.
RUN rm -f ./linux/Dockerfile && rm -f /bin/su

#Add soft links
RUN /usr/bin/python -m pip install --upgrade pip

# Add user's home directories to PATH at the front so they can install tools which
# override defaults
# Add dotnet tools to PATH so users can install a tool using dotnet tools and can execute that command from any directory
ENV PATH=~/.local/bin:~/bin:~/.dotnet/tools:$PATH

ENV AZURE_CLIENTS_SHOW_SECRETS_WARNING=True

# Set AZUREPS_HOST_ENVIRONMENT
ENV AZUREPS_HOST_ENVIRONMENT=cloud-shell/1.0
