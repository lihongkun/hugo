MSG=$1
echo $MSG
git add .
git commit -a -m "${MSG}" 
git push
hugo 
cd public
git add .
git commit -a -m "${MSG}"
git push
