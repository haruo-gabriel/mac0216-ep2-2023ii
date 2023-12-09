#!/bin/bash
# AUTOR:
# Gabriel Haruo Hanai Takeuchi;13671636;takeuchigabriel@usp.br
#
# DESCRICAO:
# Este programa é um chat que permite a comunicação entre usuários. O servidor
# é responsável por armazenar os usuários cadastrados e os usuários logados.
# O cliente é responsável por se comunicar com o servidor e com outros clientes.
# O servidor envia a lista de usuários logados para o Telegram a cada 1 minuto.
# O cliente envia mensagens para outros clientes e recebe mensagens de outros.
# O cliente também envia mensagens de erro para o Telegram.
#
# COMO EXECUTAR:
# ./ep2.sh [servidor|cliente]
#
# DEPENDENCIAS:
# Desenvolvido em Ubuntu 22.04.3 LTS on Windows 10 x86_64

#set -x

bot_url=https://api.telegram.org/bot6453136102:AAESQ5czUkEanwZrgCn7jvqHZJp9nwgXjuI
token_id=6453136102:AAESQ5czUkEanwZrgCn7jvqHZJp9nwgXjuI
chat_id=357179431
inicio_tempo=$SECONDS

#############################################

# SERVIDOR
# time
time_servidor() {
  agora_tempo=$(($SECONDS - $inicio_tempo))
  echo $agora_tempo 
}

# reset
reset() {
  # limpa os arquivos, mas nao os remove
  > usuario-data.txt
  > logados.txt
}

# quit
quit_servidor() {
  rm -f usuario-data.txt
  rm -f logados.txt
  kill $loop_telegram_pid
  exit 0
}

# list
list() {
  awk '{print $1}' logados.txt
}

#############################################

# CLIENTE
# O cliente deve suportar os seguintes comandos sem necessidade do usuario estar logado: 

# create usuario senha
create() {
  local usuario="$1"
  local senha="$2"
  # checa se o usuario ja existe
  if grep -q "^$usuario" usuario-data.txt; then
    echo "ERRO"
  fi
  # adiciona o novo usuario na base de dados
  echo "$usuario $senha" >> usuario-data.txt
}

# passwd usuario antiga nova
passwd() {
  local usuario="$1"
  local senha_antiga="$2"
  local senha_nova="$3"
  # checa se o usuario ja existe
  if grep -q "^$usuario" usuario-data.txt; then
    # checa se a senha do input corresponde a senha cadastrada
    local senha_cadastrada=$(grep "^$usuario" usuario-data.txt | cut -d ' ' -f 2)
    if [ "$senha_antiga" == "$senha_cadastrada" ]; then
      sed -i "/^$usuario /s/$senha_antiga/$senha_nova/" usuario-data.txt # troca a senha
      return 0
    else
      echo "ERRO"
    fi
  else
    echo "ERRO"
  fi
}

# login usuario senha
login() {
  local usuario="$1"
  local senha="$2"
  # checa se usuario ja existe
  if grep -q "^$usuario" usuario-data.txt; then
    # checa se a senha do input corresponde a senha cadastrada
    local senha_cadastrada=$(grep "^$usuario" usuario-data.txt | cut -d ' ' -f 2)
    if [ "$senha" == "$senha_cadastrada" ]; then
      echo "$usuario" >> logados.txt
      echo "$usuario"
      return 0 # login sucedido
    else
      return 1 # senha incorreta
    fi
  else
    return 2 # usuario nao existe
  fi
}

# quit
quit_cliente(){
  exit 0
}

# O cliente deve suportar os seguintes comandos apos o usuario logar:
# list

# logout_cliente
logout_cliente(){
  local usuario="$1"
  # cria um arquivo temporario
  local tmp_logados=$(mktemp)
  # remove o usuario de logados.txt
  grep -v "^$usuario" logados.txt > "$tmp_logados"
  mv "$tmp_logados" logados.txt
  # checa se o arquivo temporario ainda existe antes de remove-lo
  if [ -f "$tmp_logados" ]; then
    rm "$tmp_logados"
  fi
  # remove o pipe do usuario e mata o listener
  #kill $listener_pid
  rm -f "pipe_$usuario"
}

# msg destinatario mensagem
msg(){
  local destinatario="$1"
  local mensagem="${*:2}"
  # checa se o destinatario ja existe
  if grep -q "^$destinatario" usuario-data.txt; then
    # checa se o pipe do destinatario existe
    if [ -p "pipe_$destinatario" ]; then
      # envia a mensagem para o terminal local do destinatario
      echo "$usuario_logado;$mensagem" > "pipe_$destinatario"
    else
      echo "ERRO"
    fi
  fi
}
# Para todos os tres comandos acima, se o usuario nao estiver logado, deve ser impressa a string ERRO

# funcao auxiliar que monitora se o usuario recebeu mensagens
listener(){
  while true; do
    if [ -p "$pipe_inbox" ]; then
      read -r carta < "$pipe_inbox"
      if [ -n "$carta" ]; then
        # a carta é da forma "remetente;mensagem", sendo que a mensagem é todo resto da linha apos rementente
        local remetente=$(echo "$carta" | cut -f 1 -d ';')
        local mensagem=$(echo "$carta" | cut -f 2- -d ';')
        echo "
[Mensagem do $remetente]: $mensagem"
        # imprime o prompt novamente, sem quebrar a linha
        printf "cliente> "
      fi
    fi
  done &
  #done &
  #listener_pid=$!
}

#############################################

# TELEGRAM
# usuario errou a senha
errou_a_senha() {
  local usuario="$1"
  local dia_atual=$(date +"%d/%m/%Y")
  local hora_atual=$(date +"%T")
  curl -s --data "text=Usuário errou a senha no dia $dia_atual às $hora_atual" $bot_url/sendMessage?chat_id=$chat_id > /dev/null
}

# usuario logou com sucesso
logou_com_sucesso() {
  local usuario="$1"
  local dia_atual=$(date +"%d/%m/%Y")
  local hora_atual=$(date +"%T")
  curl -s --data "text=Usuário $usuario logou com sucesso no dia $dia_atual às $hora_atual" $bot_url/sendMessage?chat_id=$chat_id > /dev/null
}

# usuario deslogou
deslogou() {
  local usuario="$1"
  local dia_atual=$(date +"%d/%m/%Y")
  local hora_atual=$(date +"%T")
  curl -s --data "text=Usuário $usuario deslogou no dia $dia_atual às $hora_atual" $bot_url/sendMessage?chat_id=$chat_id > /dev/null
}

#############################################

# lacos do servidor e do cliente
if [ "$1" == "servidor" ]; then
  touch usuario-data.txt
  touch logados.txt

  while true; do
    # enviar a lista de todos os logados de 1 em 1 minuto
    curl -s --data "text=Usuários logados:%0A$(cat logados.txt)" $bot_url/sendMessage?chat_id=$chat_id > /dev/null
    sleep 60
  done &
  loop_telegram_pid=$!

  while true; do
    read -p "servidor> " input
    case $input in
      list)
        list
        ;;
      time)
        time_servidor
        ;;
      reset)
        reset
        ;;
      quit)
        quit_servidor
        ;;
      *)
        echo "Comando inválido."
        ;;
    esac
  done

elif [ "$1" == "cliente" ]; then
  usuario_logado=""
  pipe_inbox=""

  while true; do
    read -p "cliente> " input
    case $input in
      "create "*)
        input=${input#*"create "} # filtra o "create " do input
        create $input
        ;;
      "passwd "*)
        input=${input#*"passwd "} # filtra o "passwd " do input
        # checa se o codigo deu erro
        if [ "$(passwd $input)" == "ERRO" ] ; then
          echo "ERRO"
        fi
        ;;
      "login "*)
        input=${input#*"login "} # filtra o "login " do input
        if grep -q "$(echo "$input" | awk '{print $1}')" logados.txt; then # se o usuário já está logado
          echo "ERRO"
        elif [ "$usuario_logado" == "" ]; then
          output=$(login $input)
          if [ $? == 0  ]; then # se o login foi sucedido
            usuario_logado=$output
            # faz o pipe para receber mensagens
            mkfifo "pipe_$usuario_logado"
            pipe_inbox="pipe_$usuario_logado"
            # inicia o listener
            listener
            logou_com_sucesso "$usuario_logado"
          elif [ $? == 1 ]; then # se a senha esta incorreta
            errou_a_senha
            echo "ERRO"
          else # se o usuario nao existe
            echo "ERRO"
          fi
        else 
          echo "ERRO"
        fi
        ;;
      logout)
        if [ -n "$usuario_logado" ]; then
          deslogou "$usuario_logado"
          logout_cliente "$usuario_logado"
          usuario_logado=""
        else
          echo "ERRO"
        fi
        ;;
      quit)
        logout_cliente "$usuario_logado"
        quit_cliente
        ;;
      list)
        if [ -n "$usuario_logado" ]; then
          list
        else
          echo "ERRO"
        fi
        ;;
      "msg "*)
        input=${input#*"msg "} # filtra o "msg " do input
        if [ "$(msg $input)" == "ERRO" ]; then
          echo "ERRO"
        fi
        ;;
      user)
        if [ -n "$usuario_logado" ]; then
          echo "$usuario_logado"
        else
          echo "Você não está logado."
        fi
        ;;
      *)
        echo "Comando inválido."
        ;;
    esac
  done

else
  echo "Uso: $0 [servidor|cliente]"
fi

#############################################

#set +x