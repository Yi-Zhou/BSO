#!/usr/bin/env bash

# slightly modified from https://github.com/facebookresearch/MIXER/blob/master/prepareData.sh

echo 'Cloning Moses github repository (for tokenization scripts)...'
git clone https://github.com/Yi-Zhou/mosesdecoder.git


SCRIPTS=mosesdecoder/scripts
TOKENIZER=$SCRIPTS/tokenizer/tokenizer.perl
LC=$SCRIPTS/tokenizer/lowercase.perl
CLEAN=$SCRIPTS/training/clean-corpus-n.perl

URL="http://wit3.fbk.eu/archive/2014-01/texts/de/en/de-en.tgz"
GZ=de-en.tgz

if [ ! -d "$SCRIPTS" ]; then
    echo "Please set SCRIPTS variable correctly to point to Moses scripts."
    exit
fi

src=de
tgt=en
lang=de-en
prep=prep
tmp=prep/tmp
orig=orig

mkdir -p $orig $tmp $prep

echo "Downloading data from ${URL}..."
cd $orig
#http_proxy=fwdproxy:8080 https_proxy=fwdproxy:8080 
wget "$URL"

if [ -f $GZ ]; then
    echo "Data successfully downloaded."
else
    echo "Data not successfully downloaded."
    exit
fi

tar zxvf $GZ
cd ..

echo "pre-processing train data..."
for l in $src $tgt; do
    f=train.tags.$lang.$l
    tok=train.tags.$lang.tok.$l
	raw=train.tags.$lang.raw.$l

    cat $orig/$lang/$f | \
    grep -v '<url>' | \
    grep -v '<talkid>' | \
    grep -v '<keywords>' | \
    sed -e 's/<title>//g' | \
    sed -e 's/<\/title>//g' | \
    sed -e 's/<description>//g' | \
    sed -e 's/<\/description>//g' | \
    perl $TOKENIZER -threads 8 -l $l > $tmp/$tok
    echo ""

    cat $orig/$lang/$f | \
    grep -v '<url>' | \
    grep -v '<talkid>' | \
    grep -v '<keywords>' | \
    sed -e 's/<title>//g' | \
    sed -e 's/<\/title>//g' | \
    sed -e 's/<description>//g' | \
    sed -e 's/<\/description>//g' > $tmp/$raw
    echo ""
done
perl $CLEAN -ratio 1.5 $tmp/train.tags.$lang $src $tgt $tmp/train.tags.$lang.clean 1 50
for l in $src $tgt; do
    perl $LC < $tmp/train.tags.$lang.clean.$l > $tmp/train.tags.$lang.$l
    cat $tmp/train.tags.$lang.clean.$l.raw > $tmp/train.tags.$lang.raw.$l
done

echo "pre-processing valid/test data..."
for l in $src $tgt; do
    for o in `ls $orig/$lang/IWSLT14.TED*.$l.xml`; do
    fname=${o##*/}
    f=$tmp/${fname%.*}
    echo $o $f
    grep '<seg id' $o | \
        sed -e 's/<seg id="[0-9]*">\s*//g' | \
        sed -e 's/\s*<\/seg>\s*//g' | \
        sed -e "s/\’/\'/g" | \
    perl $TOKENIZER -threads 8 -l $l | \
    perl $LC > $f
    echo ""
    grep '<seg id' $o | \
        sed -e 's/<seg id="[0-9]*">\s*//g' | \
        sed -e 's/\s*<\/seg>\s*//g' | \
        sed -e "s/\’/\'/g" > $f.raw
    done
    echo ""
done


echo "creating train, valid, test..."
for l in $src $tgt; do
    awk '{if (NR%23 == 0)  print $0; }' $tmp/train.tags.$lang.$l > $prep/valid.de-en.$l
    awk '{if (NR%23 == 0)  print $0; }' $tmp/train.tags.$lang.raw.$l > $prep/valid.de-en.$l.raw
    awk '{if (NR%23 != 0)  print $0; }' $tmp/train.tags.$lang.$l > $prep/train.de-en.$l
    awk '{if (NR%23 != 0)  print $0; }' $tmp/train.tags.$lang.raw.$l > $prep/train.de-en.$l.raw

    cat $tmp/IWSLT14.TED.dev2010.de-en.$l \
        $tmp/IWSLT14.TEDX.dev2012.de-en.$l \
        $tmp/IWSLT14.TED.tst2010.de-en.$l \
        $tmp/IWSLT14.TED.tst2011.de-en.$l \
        $tmp/IWSLT14.TED.tst2012.de-en.$l \
        > $prep/test.de-en.$l
    cat $tmp/IWSLT14.TED.dev2010.de-en.$l.raw \
        $tmp/IWSLT14.TEDX.dev2012.de-en.$l.raw \
        $tmp/IWSLT14.TED.tst2010.de-en.$l.raw \
        $tmp/IWSLT14.TED.tst2011.de-en.$l.raw \
        $tmp/IWSLT14.TED.tst2012.de-en.$l.raw \
        > $prep/test.de-en.$l.raw
done

echo "writing train, valid, test..."
th makedata.lua -dstDir data -srcDir prep
