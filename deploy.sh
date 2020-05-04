MSG=$1
echo $MSG
hugo
git add .
git commit -a -m "${MSG}" 
git push