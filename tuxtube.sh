#!/bin/bash

#----------------------------------------------------------------------------------------------
# Data:			25 de Outubro de 2016
# Criado por:	SHAMAN
# Página:		http://shellscriptx.blogspot.com.br
# Script:		tuxtube.sh
# Descrição:	Script com interface (gtk/yad) utilizando o recurso dnd (arrasta e solta)
#				para realizar download de vídeos no 'youtube' através do comando 'youtube-dl'
#				permitindo ao usuário selecionar o formato de saída do video e posteriormente
#				a conversão por meio do comando 'ffmpeg'.
#				Formatos disponíveis:
#				Vídeos:	mp4, mkv, avi, ogg, webm, flv
#				Aúdio:  best, aac, vorbis, mp3, m4a, opus, wav
#----------------------------------------------------------------------------------------------

# Nome do script
SCRIPT=$(basename "$0")

# Lista os pacotes requeridos
for pkg in youtube-dl ffmpeg notify-send yad
do
	# Verifica se os pacotes estão presentes, caso contrário imprime
	# a mensagem de erro e finaliza o script com status 1
	if ! which $pkg 1>/dev/null; then
		echo "$SCRIPT: erro: pacote '$pkg' não está instalado." 1>&2
		exit 1
	fi
done

# Suprime todas as saidas.
exec &>/dev/null

# Se o script for interrompido pelo usuário, chama a função kill_proc
trap 'kill_proc' INT

# Função que mata os processos em segundo plano do 'youtube-dl' (se existir)
kill_proc(){ kill -9 $PID; killall youtube-dl; }

# Download do vídeo
down_vid()
{
	# Aplica uma expressão regular para validar a 'URI' passada no argumento,
	# verificando se é um link válido do 'youtube', caso contrário sai da função.
	if [[ ! $1 =~ ^https://www.youtube.com/watch\?v=[a-zA-Z0-9_-]+$ ]]; then
		# Mensagem erro
		yad --form \
			--fixed \
			--center \
			--title='Error' \
			--text="Link: $1\nO link do vídeo selecionado é inválido. !!!" \
			--image=gtk-dialog-error \
			--button='Ok':0

			return 0
	fi
	
	# Armazena o argumento
	URL="$1"

	# Exibe o 'form' de seleção do tipo de arquivo e armazena em 'TYPE'
	TYPE=$(yad --title='Tipo do arquivo' \
		--center \
		--width=200 \
		--height=400 \
		--fixed \
		--text='Converter vídeo para:' \
		--separator='' \
		--button='Baixar!gtk-save!Inicia o processo de download.':0 \
		--print-column=2 \
		--list --radiolist \
		--column='Opção' \
		--column='Formato' \
		TRUE 'mp4' \
		FALSE 'mkv' \
		FALSE 'avi' \
		FALSE 'ogg' \
		FALSE 'webm' \
		FALSE 'flv' \
		FALSE 'best' \
		FALSE 'aac' \
		FALSE 'vorbis' \
		FALSE 'mp3' \
		FALSE 'm4a' \
		FALSE 'opus' \
		FALSE 'wav')
		
		# Se o usuário clicou em baixar.
		if [ $? -eq 0 ]; then
			# Lê o tipo selecionado e monta os argumentos que seram
			# passados com o comando 'youtube-dl'
			case $TYPE in
					mp4|mkv|avi|ogg|webm|flv)		# Vídeo
					OPTS="--recode-video $TYPE"		# Argumentos
					;;
				best|aac|vorbis|mp3|m4a|opus|wav)				# Aúdio
					OPTS="--extract-audio --audio-format $TYPE"	# Argumentos
					;;
			esac
		
			# Obtem o título do vídeo passado na url e rediciona para o arquivo '/tmp/vid.title'
			# que será acessado posteriormente pelo 'form' de progresso.
			# O processo é executado em background.
			youtube-dl -e --get-title $URL > /tmp/vid.title &
			TPID=$!		# Salva do 'PID' do processo

			# Inicia um subshell em background
			(
				# Executa o comando com os parâmetros armazenados em 'OPTS', iniciando
				# o donwload do vídeo armazenado em 'URL' e rediciona a saida para o
				# o arquivo '/tmp/vid.prog', criando um status de progresso.
				if youtube-dl --newline $OPTS $URL > /tmp/vid.prog; then
					# Envia notificação após a conclusão do download
					notify-send --urgency=normal \
								--expire-time=5 \
								--app-name="$SCRIPT" \
								--icon="$PWD/tuxtube.icon" "$SCRIPT" "$(cat /tmp/vid.title).\nDownload concluido com sucesso."
				# Imprime mensagem de erro em caso de falha.
				else
					yad --form \
						--title='Erro' \
						--center \
						--fixed \
						--image=gtk-dialog-error \
						--text='Não foi possível realizar o download do vídeo !!!' \
						--button='OK':0 
				fi
			) &
						
			# Armazena o 'PID' do processo
			PID=$!
			
			# Exibe o 'form' de progresso enquanto o processo armazenado em 'PID' estiver em execução.
			while [ $(ps -q $PID -o comm=) ]
			do
				# Imprime as informações de progresso.
				# Título
				# Converter para
				# Progresso do download
				echo "#Título: $(cat /tmp/vid.title)\nConverter para: $TYPE\n$(awk 'END {print}' /tmp/vid.prog)"
				sleep 1
            done | yad --progress \
						--title 'Download' \
						--center \
						--fixed \
						--pulsate \
						--auto-close \
						--auto-kill \
						--button='Cancelar!gtk-cancel!Cancela o processo de download.':0
		
			# Mata os processos em background
			kill_proc
		fi
}

# Janela principal
yad --title="$SCRIPT - [SHAMAN]" \
	--text='Arraste a miniatura do vídeo para cá :D' \
	--geometry=300x300+0+0 \
	--fixed \
	--image=tuxtube.png \
	--no-buttons \
	--dnd \
	--tooltip | while read url; do down_vid $url; done	# Conecta o pipe de saida do 'form' ao 'while' que lê os
														# dados de saída quando o usuário arrasta o objeto para
														# cima do 'form', chamando a função 'down_vid' com a 
														# 'URI' armazenada em 'vid'.

exit 0
#FIM
