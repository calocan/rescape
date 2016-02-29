#!/bin/bash

VERSION='0.9.1'
OUTPUT_PATH='/tmp'
RELEASE_PATH="$OUTPUT_PATH/release"
UNZIPPED_FILE="$RELEASE_PATH/rescape-$VERSION"
ZIP_FILE="$UNZIPPED_FILE.zip"

mkdir -p $RELEASE_PATH
echo "Archiving project to $RELEASE_PATH"
rm -f $UNZIPPED_FILE
rm -f $ZIP_FILE

#The release archive is created with the following command.
echo "git archive --format zip --output $ZIP_FILE --prefix=rescape/ master"
git archive --format zip --output $ZIP_FILE --prefix=rescape/ master

#In order that rescape.rb sit at the top level of this repository, I unzip the archive, move rescape.rb to the top level, and rezip
cd $RELEASE_PATH
unzip $ZIP_FILE
cp "rescape/rescape.rb" .
#rm $ZIP_FILE
#zip -r $ZIP_FILE "rescape" "rescape.rb"
#rm -r "rescape" "rescape.rb"
cd -
