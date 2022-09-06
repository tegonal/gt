! [ -f ./install.sh ] || (echo "there is already an install.sh in your directory, aborting"; exit 1) && \
wget "https://raw.githubusercontent.com/tegonal/gget/main/install.sh" && \
wget "https://raw.githubusercontent.com/tegonal/gget/main/install.sh.sig" && \
wget -O- https://raw.githubusercontent.com/tegonal/gget/main/.gget/signing-key.public.asc | gpg --import - && \
gpg --verify ./install.sh.sig ./install.sh && \
chmod +x ./install.sh && \
echo "verification successful" || (echo "verification failed, don't continue"; exit 1) && \
./install.sh
