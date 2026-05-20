#!/bin/bash
set -e

start_nginx() {
    echo "Starting Nginx service..."
    service nginx start
}

execute_script() {
    local script_path=$1
    local script_msg=$2

    if [[ -f ${script_path} ]]; then
        echo "${script_msg}"
        bash "${script_path}"
    fi
}

setup_git_auth() {
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    if [[ -n "${GIT_SSH_PRIVATE_KEY}" ]]; then
        echo "Setting up Git SSH key..."
        printf '%s\n' "${GIT_SSH_PRIVATE_KEY}" > ~/.ssh/id_ed25519
        chmod 600 ~/.ssh/id_ed25519
        ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null || true
        chmod 644 ~/.ssh/known_hosts
        cat >> ~/.ssh/config <<'EOF'
Host github.com
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
EOF
        chmod 600 ~/.ssh/config
    fi

    if [[ -n "${GITHUB_TOKEN}" ]]; then
        echo "Setting up GitHub HTTPS auth..."
        git config --global url."https://${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"
    fi
}

setup_ssh() {
    if [[ ${PUBLIC_KEY} ]]; then
        echo "Setting up SSH..."
        mkdir -p ~/.ssh
        echo "${PUBLIC_KEY}" >> ~/.ssh/authorized_keys
        chmod 700 -R ~/.ssh

        if [[ ! -f /etc/ssh/ssh_host_rsa_key ]]; then
            ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -q -N ''
            echo "RSA key fingerprint:"
            ssh-keygen -lf /etc/ssh/ssh_host_rsa_key.pub
        fi

        if [[ ! -f /etc/ssh/ssh_host_dsa_key ]]; then
            ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -q -N ''
            echo "DSA key fingerprint:"
            ssh-keygen -lf /etc/ssh/ssh_host_dsa_key.pub
        fi

        if [[ ! -f /etc/ssh/ssh_host_ecdsa_key ]]; then
            ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -q -N ''
            echo "ECDSA key fingerprint:"
            ssh-keygen -lf /etc/ssh/ssh_host_ecdsa_key.pub
        fi

        if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
            ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -q -N ''
            echo "ED25519 key fingerprint:"
            ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
        fi

        service ssh start

        echo "SSH host keys:"
        for key in /etc/ssh/*.pub; do
            echo "Key: ${key}"
            ssh-keygen -lf "${key}"
        done
    fi
}

export_env_vars() {
    echo "Exporting environment variables..."
    printenv | grep -E '^[A-Z_][A-Z0-9_]*=' | grep -vE '^(PUBLIC_KEY|GIT_SSH_PRIVATE_KEY|GITHUB_TOKEN)=' | awk -F = '{ val = $0; sub(/^[^=]*=/, "", val); print "export " $1 "=\"" val "\"" }' > /etc/rp_environment

    if ! grep -q 'source /etc/rp_environment' ~/.bashrc; then
        echo 'source /etc/rp_environment' >> ~/.bashrc
    fi
}

start_jupyter() {
    if [[ ${JUPYTER_PASSWORD} ]]; then
        echo "Starting Jupyter Lab..."
        mkdir -p /opt
        cd /opt
        nohup jupyter lab \
            --allow-root \
            --no-browser \
            --port=8888 \
            --ip=* \
            --FileContentsManager.delete_to_trash=False \
            --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}' \
            --ServerApp.token="${JUPYTER_PASSWORD}" \
            --ServerApp.allow_origin=* \
            --ServerApp.preferred_dir=/opt \
            &> /jupyter.log &
        echo "Jupyter Lab started"
    fi
}

start_nginx
execute_script "/pre_start.sh" "Running pre-start script..."

echo "Pod Started"

setup_ssh
setup_git_auth
start_jupyter
export_env_vars

echo "Start script(s) finished, Pod is ready to use."

sleep infinity
