#!/bin/bash
# $ chmod +x new-site.sh
# ./essai.sh
# or move to /usr/local/bin

path_main="/home/sites/_VHOSTS"

wordpress_wc_to_clone="wp-starter"
wordpress_theme_to_clone="wordpress-starter-theme"

VERT="\\033[1;32m"
NORMAL="\\033[0;39m"
ROUGE="\\033[1;31m"
ROSE="\\033[1;35m"
BLEU="\\033[1;34m"
BLANC="\\033[0;02m"
BLANCLAIR="\\033[1;08m"
JAUNE="\\033[1;33m"
CYAN="\\033[1;36m"


echo ""
echo "--------------------------------------"
echo "------- CREATION PROJET : ------------"
echo "--------------------------------------"
echo ""

# PROJECT TYPE
until [ "$project_type" = "drupal" ] || [ "$project_type" = "wordpress" ]
do
    read -p 'Type de projet (wordpress/drupal) : ' project_type
done

echo "-------------"

# PROJECT SLUG
read -p 'Slug du projet : ' project_slug
project_slug_safe=${project_slug//_/}
project_slug_safe=${project_slug_safe// /_}
project_slug_safe=${project_slug_safe//[^a-zA-Z0-9_]/}
project_slug_safe=`echo -n $project_slug_safe | tr A-Z a-z`

echo "-------------"

# PROJECT HUMAN NAME
read -p 'Nom du projet : ' project_name

echo "-------------"

# PROJECT AUTHOR
read -p "Initiales de l'auteur du projet : " project_author

echo "-------------"

# PROJECT BDD USERNAME
until [ "$project_bdd_creation" = "Y" ] || [ "$project_bdd_creation" = "n" ]
do
    read -p 'Créer un nouvel utilisateur SQL ? (Y/n) ' project_bdd_creation
done

if [ "$project_bdd_creation" = "Y" ]
then
	project_bdd_user="$project_slug_safe"
	project_bdd_passwd=`mktemp XXXXXXXXXXXXXXXX`
else
	read -p "Nom du l'utilisateur existant : " project_bdd_user
	read -p "Mot de passe associé : " project_bdd_passwd
fi

echo "-------------"

# PROJECT REDMINE
until [ "$project_redmine_creation" = "Y" ] || [ "$project_redmine_creation" = "n" ]
do
    read -p 'Créer un nouveau projet sur Redmine ? (Y/n)  : ' project_redmine_creation
done

echo "-------------"





# Nom de la working copy
project_wc="$project_slug-$project_author.go"
project_wc_path="$path_main/$project_wc"

# BDD : name + user + password
project_bdd_name="$project_slug_safe""_""$project_author""_db"


echo ""
echo "Résumé :"
echo ""
echo "Dépôt GIT ..............." $project_slug'.git'
echo "Working copy ............" $project_wc
echo "BDD name ................" $project_bdd_name "( -u" $project_bdd_user "-mdp" $project_bdd_passwd ")"
echo "Nom du projet Redmine ..." $project_name
echo ""

read -p 'Confirmer les informations et initier la création ? (Y) : ' creation_confirmation
if [ "$creation_confirmation" != "Y" ]
then
	exit
fi

echo ""
echo ""



# --------------------------------------------------------------------------
# --------------------------------------------------------------------------
# --------------------------------------------------------------------------
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------

echo "$BLEU Création du dépôt GIT via gitolite $BLANC"

cd "/home/sites/gitolite-admin/conf"
git pull
sed -i -e "s/clairsienne-blog/clairsienne-blog $project_slug/g" "gitolite.conf"
git commit -am "Ajoute $project_slug"
git push

echo "$VERT| Done"

# --------------------------------------------------------------------------

echo "$BLEU Création de la Working Copy $BLANC"

mkdir "$project_wc_path"

echo "$VERT| Done"

# --------------------------------------------------------------------------

echo "$BLEU Copie du wordpress starter $BLANC"

cp -R "$path_main/$wordpress_wc_to_clone.go/web/" "$project_wc_path/web/"

echo "$VERT| Done"

# --------------------------------------------------------------------------

echo "$BLEU Initialisation du dépôt GIT $BLANC"

cd "$project_wc_path/web"
rm -rf .git

git init
git remote add origin "git@git.rc2c.fr:$project_slug.git"
git config --global user.name "Mathieu Maingret"
git config --global user.email mathieu@rc2c.fr
git add -A .
git commit -am "First commit by shell script"
git push -u origin master

echo "$VERT| Done"

# --------------------------------------------------------------------------

echo "$BLEU Modification des infos BDD dans /secrets/ $BLANC"

cd "$project_wc_path/web/secrets"
sed -i -e "s/wordbox_smarter_db/$project_bdd_name/g" "keys.php"
sed -i -e "s/wordpress/$project_bdd_user/g" "keys.php"
sed -i -e "s/C9L8TBWLfmaxsdKD/$project_bdd_passwd/g" "keys.php"

echo "$VERT| Done"

# --------------------------------------------------------------------------

echo "$BLEU Modification des infos de déploiement dans /config/ $BLANC"

cd "$project_wc_path/web/config"
sed -i -e "s/wordbox/$project_slug/g" "deploy.rb"

echo "$VERT| Done"

# --------------------------------------------------------------------------

echo "$BLEU Création de la BDD sur PHPMyAdmin $BLANC"

mysql -e "CREATE USER '$project_bdd_user'@'localhost' IDENTIFIED BY '$project_bdd_passwd';
GRANT USAGE ON * . * TO  '$project_bdd_user'@'localhost' IDENTIFIED BY '$project_bdd_passwd' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0 ;
CREATE DATABASE $project_bdd_name;
GRANT ALL PRIVILEGES ON $project_bdd_name.* TO  '$project_bdd_user'@'localhost' WITH GRANT OPTION ;
exit"

cd "$project_wc_path/web/"
mysqldump --no-create-db wordbox_smarter_db > dump.sql
`mysql -h '.$secrets['database_host'].' -D '.$secrets['database_name'].' -u '.$secrets['database_user'].' --password='.$secrets['database_pass'].' < dump.sql`

echo "$VERT| Done"

# --------------------------------------------------------------------------

echo "$BLEU Renommage du dossier du thème $BLANC"

# Rename theme folder
cp -R "$project_wc_path/web/wp-content/themes/$wordpress_theme_to_clone" "$project_wc_path/web/wp-content/themes/$project_slug"
rm -rf "$project_wc_path/web/wp-content/themes/$wordpress_theme_to_clone"
# Edit theme description in styles.css
sed -i "s/WP Starter v1/$project_name/g" "$project_wc_path/web/wp-content/themes/$project_slug/style.css"

echo "$VERT| Done"

# --------------------------------------------------------------------------

if [ "$project_redmine_creation" != "Y" ]
then
	echo "$BLEU Ajout du projet Redmine $BLANC"
	echo "$VERT| Done"
fi

# --------------------------------------------------------------------------

echo "$BLEU Mise à jour des plugins via composer $BLANC"

cd "$project_wc_path/web"
export PATH=/usr/local/php-5.4/bin/:$PATH
composer update

echo "$VERT| Done"

# --------------------------------------------------------------------------

echo "$CYAN Projet créé ! Let's gow ! $BLANC"