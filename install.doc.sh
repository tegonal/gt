currentDir=$(pwd) && \
tmpDir=$(mktemp -d -t gget-download-install-XXXXXXXXXX) && cd "$tmpDir" && \
wget "https://raw.githubusercontent.com/tegonal/gget/main/.gget/signing-key.public.asc" && \
wget "https://raw.githubusercontent.com/tegonal/gget/main/.gget/signing-key.public.asc.sig" && \
gpg --verify ./signing-key.public.asc.sig ./signing-key.public.asc && \
echo "public key trusted" && \
mkdir ./gpg && \
gpg --homedir ./gpg --import ./signing-key.public.asc && \
wget "https://raw.githubusercontent.com/tegonal/gget/main/install.sh" && \
wget "https://raw.githubusercontent.com/tegonal/gget/main/install.sh.sig" && \
gpg --homedir ./gpg --verify ./install.sh.sig ./install.sh && \
chmod +x ./install.sh && \
echo "verification successful" || (echo "verification failed, don't continue"; exit 1) && \
./install.sh && result=true || (echo "installation failed"; exit 1) && \
false || cd "$currentDir" && rm -r "$tmpDir" && "${result:-false}"
