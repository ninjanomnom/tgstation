#!/bin/bash

DEPENDENCIES_FOLDER="code/_dependencies"
COMPONENTS_REPO="https://github.com/ninjanomnom/components.git"
COMPONENTS_NAME="dcs"
COMPONENTS_VERSION="origin/master"

echo "Setting up dependencies:"

#Checks if dependency folder exists and makes it if not
if [ ! -d $DEPENDENCIES_FOLDER ]; then
	mkdir $DEPENDENCIES_FOLDER
fi

cd $DEPENDENCIES_FOLDER

#If the folder exists the dependency has been cloned before
if [ ! -d $COMPONENTS_NAME ]; then
	git clone $COMPONENTS_REPO $COMPONENTS_NAME
fi

cd $COMPONENTS_NAME

#Checks if the git status contains "modified" which means someone made changes.
#They shouldn't have but we wont be mean and throw their changes away.
case "$(git status)" in
	*modified*)
		echo "Changes were found while updating dependency $COMPONENTS_NAME changes have been stashed"
		git stash
esac

git fetch origin
git reset --hard $COMPONENTS_VERSION

read PAUSE
