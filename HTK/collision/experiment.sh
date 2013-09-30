
# 引数をつけて実行すると部分的に実行できる。
# 引数は、ex[1-15] が指定できる。
if [ $# -eq 0 ]; then 
    EXEC=ALL;
else
    EXEC=$1;
fi

if [ $EXEC = ex2 ] || [ $EXEC = ALL ];then
########################################################## 
# 音声ファイルから HTK 形式の 特徴量（MFCC）ファイルの抽出
# 
#  HCopy を使う．
#  ・-C オプションで指定する config ファイル（ ../config/HCopy.config ）の中身を理解すること．
#  ・-S オプションに指定する入力と出力の対応関係を記述するファイルのフォーマットを理解すること．

HCopyConf=config/config.HCopy
HCopyScp=./HCopy.scp

# $HCopyScp を作成する前に，既に $HCopyScp が存在していたならそれを削除する．
rm -f $HCopyScp

# -S オプションに指定するファイル（$HCopyScp）の作成
for wavFile in wav/*.wav; do
    # /wav/ を /mfcc/ に，.wav を .mfcc に置換する．
    mfccFile=$( echo $wavFile | sed -e "s@wav/@mfcc/@g" -e "s@.wav@.mfcc@g" )
    # $HCopyScp ファイルに書き出す．
    echo "$wavFile $mfccFile" >> $HCopyScp
done

# HCopy して MFCC_E_D_Z を抽出．
#   -T 1     verbose にするオプション．
#   -C file  config ファイルを指定するオプション．
#   -S file  入力の音声ファイルと出力の特徴量ファイルの名前を指定するテキストファイルを読み込む．
HCopy -T 1 -C $HCopyConf -S $HCopyScp

# 参考
# raw ファイル(ここでは .ad のファイル）を wav ファイルに変換したいときは sox コマンドを使う。
# sox -sx -b 16 -r 16000 -t raw [input.ad] -t wav [output.wav]
# -s    signed integer ( 注：符号付き整数型であるという意味，Cのintではない )
# -b 16 16bit(=2byte)型
# -x    endian swap ( HTK で使うファイルはビッグエンディアンのため )
#
# play -sx -b 16 -r 16000 -t raw [input.ad]
# とすれば直接再生することもできる
#
# wav -> ad
# sox -t wav [input.wav] -x -t raw [output.ad]

# 音声ファイルから HTK 形式の 特徴量（MFCC）ファイルの抽出 おわり
#################################################################
fi

if [ $EXEC = ex3 ] || [ $EXEC = ALL ];then
######################################################################## 
# 音素 HMM を学習するために，すべての音素で共通な HMM の初期モデルを作成
# 
#  HCompV を使う．
#  ・-C オプションで指定する config ファイル（../config/config.train）の中身を理解すること．
#  ・proto_5sates のような，HMM のモデルパラメータを記述するファイルの書式を理解すること．

HCompVConf=./config/config.train
outputDir=./model/HCompV
protoHmm=./proto_5states

# HCompV して全音素共通の HMM 初期モデルを作成．
#   -T 1     verbose にするオプション．
#   -C file  config ファイルを指定するオプション．
#   -m       HMM の出力確率分布である正規分布の，平均値も変化させるためのオプション．
#   -v num   分散が小さくなりすぎる問題を解決するため，分散の最小値を num にするオプション．
#   -M dir   出力ファイルを置くディレクトリの指定．
HCompV -T 1 -C $HCompVConf -m -v 0.01 -M $outputDir $protoHmm ./mfcc/Train*.mfcc

# ここで，./proto_5states と，../model/phone/mono-mix1-0/proto_5states を見比べてみること．

# HCompV で作成した全音素で共通な HMM の初期状態を，すべての音素 HMM に割り当てる．
#   ./mkhmmdefs.pl  プログラムに少し自信がある人は中身を読んでみること．無理して理解する必要はない．
#   monophones      今回用いるすべての音素を記述したファイル．
./config/mkhmmdefs.pl $outputDir/$protoHmm config/phones > $outputDir/hmmdefs

# ここで，../model/phone/mono-mix1-0/proto_5states と
# ../model/phone/mono-mix1-0/hmmdefs.${sex} を見比べてみること．

# 音素 HMM を学習するために，すべての音素で共通な HMM の初期モデルを作成 おわり
###############################################################################
fi


if [ $EXEC = ex4 ] || [ $EXEC = ALL ];then
#####################
# 音素 HMM を学習する
# 
#  HERest を使う．
#  ・ -I オプションで指定するマスターラベルファイルの書式を理解すること．

HERestConf=./config/config.rec
inputHmm=./model/HCompV/hmmdefs
outputDir=./model/FS/
mlfFile=./lab/train.mlf
phoneList=./phone.hmm
mfccdir=./mfcc


# HERest して HMM を学習する．
#   -T 1     verbose にするオプション．
#   -C file  config ファイルを指定するオプション．
#   -v num   分散が小さくなりすぎる問題を解決するため，分散の最小値を num にするオプション．
#   -H file  学習する前の HMM の指定．
#   -M dir   出力ファイルを置くディレクトリの指定．
#   -I file  特徴量データに対して音素ラベルの対応付けを行うマスターラベルファイルを指定するオプション．
#   引数1    学習する音素 HMM の音素をリストしたファイル
#   引数2    学習に用いるデータ
HERest -T 1 -C $HERestConf -v 0.01 -H $inputHmm -M $outputDir -I $mlfFile $phoneList ${mfccdir}/Train*.mfcc

# 音素 HMM を学習する おわり
############################
fi

if [ $EXEC = ex5 ] || [ $EXEC = ALL ];then
##############################################################################
# 音素 HMM を使って ../speech/digits/ 以下に含まれる数字読み上げ音声を認識する
#
#  HVite を使う．
#  ・ネットワーク文法の作成方法を覚えること
#  ・HVite の出力の意味を理解すること

grammerFile=./grammer/FS.phone.grammer
wordnetFile=./grammer/FS.phone.ltc

HViteConf=./config/config.rec
inputHmm=./model/FS/hmmdefs
dicFile=./grammer/FS.phone.dic
phoneList=./phone.hmm

# grammerFile（人間が書けるネットワーク文法）を，HVite が読める wordnet 形式に変換する
HParse $grammerFile $wordnetFile

# HVite で音声認識する
#   -T 1     verbose にするオプション．
#   -C file  config ファイルを指定するオプション．
#   -o N     認識結果を出力するファイルに対数尤度も記述させるオプション．
#   -w file  ネットワーク文法を wordnet 形式で記述したファイル
#   -H file  使用する HMM の指定．
#   -y hoge  HVite による認識結果は，認識する *.mfcc ファイルの拡張子を .rec に変えたファイルに出力される．
#            ただし，この -y hoge オプションをしておくと，.rec の代わりに .hoge に出力される．
#   引数1    認識する単語の辞書ファイル
#   引数2    学習する音素 HMM の音素をリストしたファイル
#   引数3    認識するデータ
HVite -T 1 -C $HViteConf -o N -w $wordnetFile -H $inputHmm -y rec1 $dicFile $phoneList ./mfcc/Test*.mfcc

# 出力ファイル（ .rec1 ）の中身を見てみること．

# 音素 HMM を使って ../speech/digits/ 以下に含まれる数字読み上げ音声を認識する おわり
#####################################################################################
fi

if [ $EXEC = ex6 ] || [ $EXEC = ALL ];then
##############################################
# HVite の結果，認識率がどうなったかを出力する
# 
#  HResults を使う．
#  ・HRestults の出力の意味を理解する．

mlfFile=../lab/digit2.mlf
phoneList=./phone.hmm

# HResults で認識率を計算する
#   -T 1     verbose にするオプション．
#   -I file  認識した音声に対する，正解を指定するマスターラベルファイル
#   引数1    音素 HMM の音素をリストしたファイル（なぜか必要．）
#   引数2    集計すべき .rec ファイル
HResults -T 1 -I $mlfFile $phoneList ../mfcc/digit/*.rec1

# HVite の結果，認識率がどうなったかを出力する おわり
#####################################################
fi

if [ $EXEC = ex7 ] || [ $EXEC = ALL ];then
#####################################################
#  学習をもう一回行って，認識率や尤度の変化をみる
# 

HERestConf=./config/config.rec
inputHmm=./model/FS/hmmdefs
outputDir=./model/FS2
mlfFile=./lab/train.mlf
phoneList=./phone.hmm

# 2 回目の学習
HERest -T 1 -C $HERestConf -v 0.01 -H $inputHmm -M $outputDir -I $mlfFile $phoneList ./mfcc/Train*.mfcc

HViteConf=./config/config.rec
wordnetFile=./grammer/FS.phone.ltc
inputHmm=./model/FS2/hmmdefs
dicFile=./grammer/FS.phone.dic
phoneList=./phone.hmm

# 2 回目の認識
HVite -T 1 -C $HViteConf -o N -w $wordnetFile -H $inputHmm -y rec2 $dicFile $phoneList ./mfcc/Test*.mfcc

#  学習をもう一回行って，認識率や尤度の変化をみる おわり
########################################################
fi


if [ $EXEC = ex8 ] || [ $EXEC = ALL ];then
#####################################################
#  学習をもう一回行って，認識率や尤度の変化をみる
# 

HERestConf=./config/config.rec
inputHmm=./model/FS2/hmmdefs
outputDir=./model/FS3
mlfFile=./lab/train.mlf
phoneList=./phone.hmm
resultpostfix=rec3

# 2 回目の学習
HERest -T 1 -C $HERestConf -v 0.01 -H $inputHmm -M $outputDir -I $mlfFile $phoneList ./mfcc/Train*.mfcc

HViteConf=./config/config.rec
wordnetFile=./grammer/FS.phone.ltc
inputHmm=${outputDir}/hmmdefs
dicFile=./grammer/FS.phone.dic
phoneList=./phone.hmm

# 2 回目の認識
HVite -T 1 -C $HViteConf -o N -w $wordnetFile -H $inputHmm -y ${resultpostfix} $dicFile $phoneList ./mfcc/Test*.mfcc

#  学習をもう一回行って，認識率や尤度の変化をみる おわり
########################################################
fi

if [ $EXEC = ex9 ] || [ $EXEC = ALL ];then
#####################################################
#  学習をもう一回行って，認識率や尤度の変化をみる
# 

HERestConf=./config/config.rec
inputHmm=./model/FS3/hmmdefs
outputDir=./model/FS4
mlfFile=./lab/train.mlf
phoneList=./phone.hmm
resultpostfix=rec4

# 2 回目の学習
HERest -T 1 -C $HERestConf -v 0.01 -H $inputHmm -M $outputDir -I $mlfFile $phoneList ./mfcc/Train*.mfcc

HViteConf=./config/config.rec
wordnetFile=./grammer/FS.phone.ltc
inputHmm=${outputDir}/hmmdefs
dicFile=./grammer/FS.phone.dic
phoneList=./phone.hmm

# 2 回目の認識
HVite -T 1 -C $HViteConf -o N -w $wordnetFile -H $inputHmm -y ${resultpostfix} $dicFile $phoneList ./mfcc/Test*.mfcc

#  学習をもう一回行って，認識率や尤度の変化をみる おわり
########################################################
fi


exit 
if [ $EXEC = ex10 ] || [ $EXEC = ALL ];then
#########################################################################
# HMM の出力確率分布を，正規分布を，GMMにする（混合数を上げる）
# 
# HHEd に，HMM をどう編集するかを記述した .hed ファイルを与えることで HMM を編集することができる．
# 
inputHmm=../model/phone/IPA97-2/hmmdefs.${sex}
outputHmm=../model/phone/IPA97-mix2-0
hedFile=./mix2.hed
phoneList=./phone.hmm

# HHEd で HMM の出力確率分布の混合数を上げる
#   -T 1     verbose にするオプション
#   -H file  編集する前の HMM の指定．
#   -M dir   出力ファイルを置くディレクトリの指定．
#   引数1    「混合数を 2 にする」と書かれた .hed ファイル
#   引数2    音素 HMM に含まれる音素のリスト
HHEd -T 1 -H $inputHmm -M $outputHmm $hedFile $phoneList

# ./mix2.hed を読んでみること．
# ../model/phone/IPA97-mix2-0/hmmdefs.${sex} を確認してみること．

HERestConf=../config/config.rec
inputHmm=../model/phone/IPA97-mix2-0/hmmdefs.${sex}
outputDir=../model/phone/IPA97-mix2-1
mlfFile=../lab/train.mlf
phoneList=./phone.hmm

# 1 回目の学習
HERest -T 1 -C $HERestConf -v 0.01 -H $inputHmm -M $outputDir -I $mlfFile $phoneList ../mfcc/balance.${sex}/*.mfcc

HViteConf=../config/config.rec
wordnetFile=./digit2.phone.ltc
inputHmm=../model/phone/IPA97-mix2-1/hmmdefs.${sex}
dicFile=./digit2.phone.dic
phoneList=./phone.hmm

# 1 回目の認識
HVite -T 1 -C $HViteConf -o N -w $wordnetFile -H $inputHmm -y rec6 $dicFile $phoneList ../mfcc/digit/d*.mfcc

mlfFile=../lab/digit2.mlf
phoneList=./phone.hmm

# 1 回目の結果集計
HResults -T 1 -I $mlfFile $phoneList ../mfcc/digit/*.rec6

HERestConf=../config/config.rec
inputHmm=../model/phone/IPA97-mix2-1/hmmdefs.${sex}
outputDir=../model/phone/IPA97-mix2-2
mlfFile=../lab/train.mlf
phoneList=./phone.hmm

# 2 回目の学習
HERest -T 1 -C $HERestConf -v 0.01 -H $inputHmm -M $outputDir -I $mlfFile $phoneList ../mfcc/balance.${sex}/*.mfcc

HViteConf=../config/config.rec
wordnetFile=./digit2.phone.ltc
inputHmm=../model/phone/IPA97-mix2-2/hmmdefs.${sex}
dicFile=./digit2.phone.dic
phoneList=./phone.hmm

# 2 回目の認識
HVite -T 1 -C $HViteConf -o N -w $wordnetFile -H $inputHmm -y rec7 $dicFile $phoneList ../mfcc/digit/d*.mfcc

mlfFile=../lab/digit2.mlf
phoneList=./phone.hmm

# 2 回目の結果集計
HResults -T 1 -I $mlfFile $phoneList ../mfcc/digit/*.rec7

# HMM の出力確率分布を，正規分布を，GMMにする（混合数を上げる）おわり
#########################################################################
fi

if [ $EXEC = ex11 ] || [ $EXEC = ALL ];then
##########################################################################
# MLLR による話者適応
# この課題は余力のあるもののみでよい．（勉強会の時間内では扱わない可能性が高い）
#
# あらかじめ，HHEd を使って，HMM に MLLR のための回帰木を埋め込んでおく．
# 次に，HERest と少量の話者データを用いてを使って話者適応を行う．

# HMM の初期状態には，既存の不特定話者音素 HMM（../model/phone/IPA97-mix16-0/hmmdefs） を利用する

inputHmm=../model/phone/IPA97-mix16-0/hmmdefs
outputDir=../model/phone/IPA97-mix16-1
hedFile=./mllr_mono-mix16.hed
phoneList=./phone.hmm

# HHEd で HMM に 回帰木情報を組み込む．回帰木は，出力確率分布をボトムアップクラスタリングすることで行う．
#   -T 1     verbose にするオプション
#   -H file  編集する前の HMM の指定．
#   -M dir   出力ファイルを置くディレクトリの指定．
#   引数1    「回帰木を作る」と書かれた .hed ファイル
#   引数2    音素 HMM に含まれる音素のリスト
HHEd -T 1 -H $inputHmm -M $outputDir $hedFile $phoneList

# for HTK 3.4.1 
# hmmdefs をコピーしてやる必要がある
cp $inputHmm $outputDir/hmmdefs

# ${outputHmm} の下に回帰木情報が出力されているのでそれを確認する．

HERestConf1=../config/config.train
HERestConf2=../config/config.adapt
mlfFile=../lab/train.mlf
inputHmm1=../model/phone/IPA97-mix16-1/hmmdefs
inputHmm2=../model/phone/IPA97-mix16-1/rtree.base
outputDir=../model/phone/IPA97-mix16-2
pattern=../mfcc/%%%%%%%.${sex}/*.mfcc
phoneList=./phone.hmm

# HERest で 話者適応を行う．適応用のデータには，最初の実験の学習データにしていた 50 文すべてのデータを用いる．
#   -T 1         verbose にするオプション
#   -C file      config ファイルを指定するオプション．（複数指定可能）
#   -I file      特徴量データに対して音素ラベルの対応付けを行うマスターラベルファイルを指定するオプション．
#   -H file      編集する前の HMM の指定．（複数指定可能）
#   -K dir       話者適応の場合の，出力ファイルを置くディレクトリの指定．
#   -h 'pattern' 適応する話者の特徴量ファイルに付けられた名前のパターンを指定する．HTKBook 参照．
#   -u a         adapataion を行う，という意味．
#   引数1        学習する音素 HMM の音素をリストしたファイル
#   引数2        適応に用いるデータ．-h で指定したパターンのものが用いられる．
HERest -T 1 -C $HERestConf1 -C $HERestConf2 -I $mlfFile -H $inputHmm1 -H $inputHmm2 -K $outputDir -h ${pattern} -u a $phoneList ../mfcc/balance.${sex}/*.mfcc

# 適応後の HMM は，$outputDir/hmmdefs.balance に出力されるので check する．

HViteConf=../config/config.rec
wordnetFile=./digit2.phone.ltc
inputHmm=../model/phone/IPA97-mix16-2/hmmdefs.balance
dicFile=./digit2.phone.dic
phoneList=./phone.hmm

# HVite で認識
HVite -T 1 -C $HViteConf -o N -w $wordnetFile -H $inputHmm -y rec8 $dicFile $phoneList ../mfcc/digit/d*.mfcc

mlfFile=../lab/digit2.mlf
phoneList=./phone.hmm

# HResults で結果集計
HResults -T 1 -I $mlfFile $phoneList ../mfcc/digit/*.rec8

# triphone HMM（ triphone に関しては，また今度勉強会で取り扱う）でも，同様に適応処理できる．
# ../model/phone/tri-2000x16-0/ の下に，回帰木情報付きの triphone HMM が置いてあるので，それを適応してみる．
HERestConf1=../config/config.train
HERestConf2=../config/config.adapt-tri
mlfFile=../lab/train-tri.mlf
inputHmm1=../model/phone/tri-2000x16-0/hmmdefs
inputHmm2=../model/phone/tri-2000x16-0/rtree.base
outputDir=../model/phone/tri-2000x16-1
pattern=../mfcc/%%%%%%%.${sex}/*.mfcc
phoneList=./logicalTri

# HERest で 話者適応を行う．適応用のデータには，最初の実験の学習データにしていた 50 文すべてのデータを用いる．
HERest -T 1 -C $HERestConf1 -C $HERestConf2 -I $mlfFile -H $inputHmm1 -H $inputHmm2 -K $outputDir -h ${pattern} -u a $phoneList ../mfcc/balance.${sex}/*.mfcc

HViteConf=../config/config.rec
wordnetFile=./digit2.phone.ltc
inputHmm=../model/phone/tri-2000x16-1/hmmdefs.balance
dicFile=./digit2.phone.dic
phoneList=./phone.hmm

# HVite で認識
HVite -T 1 -C $HViteConf -o N -w $wordnetFile -H $inputHmm -y rec9 $dicFile $phoneList ../mfcc/digit/d*.mfcc

mlfFile=../lab/digit2.mlf
phoneList=./phone.hmm

# HResults で結果集計
HResults -T 1 -I $mlfFile $phoneList ../mfcc/digit/*.rec9

# MLLR による話者適応 おわり
##########################################################################
fi

if [ $EXEC = ex12 ] || [ $EXEC = ALL ];then
#######################################################################
# 音素単位ではなく，単語単位 HMM を用いた音声認識
# 
# 単語 HMM の初期状態は，音素 HMM を適当に並べれば作れる．
# 単語 HMM は，HERest ではなくHRest で学習する． 

# 実は，音素 HMM を並べて数字の単語 HMM にしたものは，../model/digit/IPA97-0 にもう入っているので，それを見てみること．
# ../model/digit/IPA97-0/hmmdefs.male を適当にくっつけることで ZERO や ICHI などができていることを check してみること．
# 自分で音素 HMM から単語 HMM を作りたい場合は，同じディレクトリに入っている pickup.c をコンパイルして使用すればよい．

# 単語 HMM のファイル名は，単語と同じである必要があるため，
# たとえば hoge という単語に対し hoge.male というファイル名をつけることができない．
# それを シンボリックリンクを使うことで解決してやる．（./make_model2.csh で自動的に行われる）
export GENDER=${sex}
cd ../model/digit/IPA97-0
#./make_models2.csh
./make_models2.bash
cd -

HRestConf=../config/config.train
outputDir=../model/digit/IPA97-1
inputDir=../model/digit/IPA97-0

# HRest して単語 HMM を学習する．
#   -T 1     verbose にするオプション．
#   -i num   バウムウェルチアルゴリズムで HMM を学習するときの iteration の回数の最大値
#   -C file  config ファイルを指定するオプション．
#   -v num   分散が小さくなりすぎる問題を解決するため，分散の最小値を num にするオプション．
#   -M dir   出力ファイルを置くディレクトリの指定．
#   引数1    学習する前の単語 HMM の指定．
#   引数2    学習に用いるデータ

# HRest は，単語ごとに回す．
for num_t in ZERO-0 ICHI-1 NI-2 SAN-3 YON-4 GO-5 ROKU-6 SHICHI-7 HACHI-8 KYU-9; do
    hmmFile=$(echo $num_t | sed "s/-.*//g")
    num=$(echo $num_t | sed "s/.*-//g")
    # 各数字につき 5 回発声されているが，ここではそのうち 4 回分を使って学習する．
    HRest -T 1 -i 40 -C $HRestConf -v 0.01 -M $outputDir $inputDir/$hmmFile ../mfcc/digit/d${num}[1-4]*.mfcc
done

fi

######################################################################
if [ $EXEC = ex13 ] || [ $EXEC = ALL ];then

HViteConf=../config/config.rec
wordnetFile=./digit2.ltc
inputDir=../model/digit/IPA97-1
dicFile=./digit2.dic
wordList=./digit2.hmm

# HVite で音声認識する
#   -T 1     verbose にするオプション．
#   -C file  config ファイルを指定するオプション．
#   -o N     認識結果を出力するファイルに対数尤度も記述させるオプション．
#   -w file  ネットワーク文法を wordnet 形式で記述したファイル
#   -d dir   使用する HMM ファイル（単語と同じ名前である必要がある）が置いてあるディレクトリの指定
#   -y hoge  HVite による認識結果は，認識する *.mfcc ファイルの拡張子を .rec に変えたファイルに出力される．
#            ただし，この -y hoge オプションをしておくと，.rec の代わりに .hoge に出力される．
#   引数1    認識する単語の辞書ファイル
#   引数2    学習する単語 HMM の単語をリストしたファイル
#   引数3    認識するデータ

# HRest で使っていない，5 回目の発声を，先でつくった単語 HMM で認識（HVite）する．
HVite -T 1 -C $HViteConf -o N -w $wordnetFile -d $inputDir -y rec10 $dicFile $wordList ../mfcc/digit/d?5.mfcc

mlfFile=../lab/digit2.mlf
wordList=./digit2.hmm

# HResults で結果を集計
HResults -T 1 -I $mlfFile $phoneList ../mfcc/digit/*.rec10

fi
