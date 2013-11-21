# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/bin

export PATH=/root/.wp-cli/bin:$PATH
source ~/wp-cli/utils/wp-completion.bash

alias get_composer="curl -s https://getcomposer.org/installer | php -d allow_url_fopen=1 -d suhosin.executor.include.whitelist=phar"
alias composer="php -d memory_limit=512M -d allow_url_fopen=1 -d suhosin.executor.include.whitelist=phar composer.phar"
alias wp="~/wp-cli/bin/wp"