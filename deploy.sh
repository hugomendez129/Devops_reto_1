#!/bin/bash
#deploy.sh
separador (){
echo -e  "\n-----------------------\n"
}
#funcion de git
funcion_git(){
if [ -d "$repo" ]; then
        echo "Existe el el repositorio de la aplicacion"
		cd $repo
		git pull
		#chequeo que se cambio el nombre de index.html para no pisarlo esto es solo cuando hago el pull
else
        echo "Se clona el repositorio de la aplicacion"
        git clone https://github.com/roxsross/$repo.git
		cd $repo
		#se hace un checkout porque no es una rama
		git checkout clase2-linux-bash
		mv /var/www/html/index.html /var/www/html/index.html.bkp
		cp -r app-295devops-travel/* /var/www/html/
fi
		}

# variables
APP=(apache2 git mariadb-server php libapache2-mod-php php-mysql php-mbstring php-zip php-gd php-json php-curl)
repo="bootcamp-devops-2023"

#compruebo si soy root
echo "Verificando que eres el usuario root"
user=$(id -u)
if [ $user -eq 0 ];then
echo "Eres el usuario root"
else
echo "no eres root se cancela el DEPLOY"
exit
fi

#actualizo 
echo "ACTUALIZANDO"
sleep 3
apt update
separador

#si se necesita agregar mas app se agregar al archivo no al sh
for i in "${APP[@]}";do
	echo "VERIFICANDO QUE ESTE INSTALADO $i" 
	separador
if dpkg -l | grep -q $i; then
		echo "esta instalado $i"
		separador
		#aunque este instalado el git mando a clonar esto es porque el git lo trae por defecto ubuntu en mi caso
		if [ "$i" = "git" ]; then
		#despues de instalar verifico si existe hago un pull si no existe un clone
		funcion_git
		separador
		fi
else
        echo "empieza a instalar $i"
        apt install -y $i
		sleep 2
		separador
        echo "SE INSTALO EL $i"
        separador
	    if [ "$i" = "mariadb-server" ]; then
		#Se Empieza a configurar MARIADB
			systemctl enable mariadb
			systemctl start mariadb
			separador
			#solicito Usuario de la DB
			echo "Ingrese Usuario:"
			read usuario
			#Solicito pass de la DB
			echo "Ingrese contraseña de DB:"
			read pasw
			separador
			###Configuracion de la base de datos
			mysql -e "CREATE USER '$usuario'@localhost IDENTIFIED BY '$pasw'";
			mysql -e "SELECT User FROM mysql.user";
			mysql -e "CREATE DATABASE devopstravel";
			mysql -e "GRANT ALL PRIVILEGES ON *.* TO '$usuario'@'localhost'";
			mysql -e "FLUSH PRIVILEGES;";
			#Ejecuto el sql
            mysql < /var/www/html/database/devopstravel.sql
			sleep 2
			sed -i 's/$dbUsername = "codeuser";/$dbUsername = "'$usuario'";/' /var/www/html/config.php
			sleep 2
			sed -i 's/$dbPassword = "";/$dbPassword = "'$pasw'";/' /var/www/html/config.php
			sleep 2
			separador
			echo "Estado del servicio $i"
			separador
			systemctl status mariadb | grep active
			separador
		fi
#verifico si tengo que instalar git y clono el repositorio
		if [ "$i" = "git" ]; then
		#despues de instalar verifico si existe hago un pull si no existe un clone
		funcion_git
		separdor
		fi
		
		if [ "$i" = "apache2" ]; then
		echo "Habilito e inicio $i"
		sed -i 's/DirectoryIndex index.html index.cgi index.pl index.php index.xhtml index.htm/DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm/' /etc/apache2/mods-enabled/dir.conf
		#Inicio y habilito el servicio Apache
		systemctl enable apache2 
		systemctl start apache2 
		separador
		echo "Estado del servicio $i"
		separador
		systemctl status $i | grep active
		separador
		fi
		
sleep 5
 fi
done

systemctl restart apache2

version=$(php -v)
echo "la version del $version"
separador
echo "Testeo PHP"
separador
if curl -I http://localhost/info.php 2>/dev/null | grep -q "HTTP/1.1 200 OK"; then
echo "Test OK."
separador
else
echo "Test con error."
separador
fi

#Discord deploy-bootcamp
discord="https://discord.com/api/webhooks/1169002249939329156/7MOorDwzym-yBUs3gp0k5q7HyA42M5eYjfjpZgEwmAx1vVVcLgnlSh4TmtqZqCtbupov"
#discord  personal
#discord="https://discord.com/api/webhooks/1175525598282649630/XX-d8vAGt8iRWWz4JQOznxeqfYcjOzBZn8zkUaTrXtBbndh_QzSGmWXslOtCHYHi0waD"

if curl -I http://localhost 2>/dev/null | grep -q "HTTP/1.1 200 OK"; then
    echo "Test OK."
    #ajusto la informacion y lo coloco tipo json
    Author="Author: $(git log -1 --pretty=format:'%an')"
    Commit="Commit: $(git rev-parse --short HEAD)"
    descripcion="Descripción: $(git log -1 --pretty=format:'%s')"
    grupo="Grupo: 25"
    status="STATUS: Despliegue WEB 295devops-travel OK"
    msj="$Author\n$Commit\n$descripcion\n$grupo\n$status"
  separador
  curl -X POST -H "Content-Type: application/json" -d "{\"content\":\"$msj\"}" "$discord"
else
    echo "Test con error."
  separador
  curl -X POST -H "Content-Type: application/json" -d "{\"content\":\"WEB 295devops-travel con ERROR\"}" "$discord"
fi

echo "Fin del deploy"

exit