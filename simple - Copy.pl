#!/usr/bin/perl


use utf8;
use XML::LibXML;
use Image::Magick;
use MIME::Base64;
use File::Find;
use Encode;
use DBI;
use Data::Dumper;



my $NumberOfPage=1;
my $MaxPages=1;
my $FileOfCurrentBook='';
my $QueryString;
my $add;

my $dbh=DBI->connect("dbi:SQLite:dbname=Library1409.db","","") or die $_;



my @columns= ("Num","Autor","Name of Book","Genre","Year","Read","Filename","Rating");
my @dataOfBook;




#Обработка рейтинга





sub onClickButtonRescan{
my $open_dialog = Gtk3::FileChooserDialog->new('Pick a file',
$window,
'select_folder',
('gtk-cancel', 'cancel',
'gtk-open', 'accept'));
$open_dialog->set_local_only(FALSE);

# dialog always on top of the textview window
$open_dialog->set_modal(TRUE);
$QueryString="none";
$open_dialog->signal_connect('response' => \&open_response_cb);
$open_dialog->show();
}


sub ReadInfoBookFromDB {
my ($SearchString)=@_;
my $sth1;
my $SearchStringL;
$SearchStringL=ucfirst($SearchString);

$QueryString="select distinct * from books where ( Name like \"%$SearchString%\"
or Author like \"%$SearchString%\"
or Author like \"%$SearchStringL%\"
or Genre like \"%$SearchString%\"
or Year like \"%$SearchString%\"
or Filename like \"%$SearchString%\"
or  Name like \"%$SearchStringL%\"
)

";

if ($SearchString eq ""){
 $sth1=$dbh->prepare("select distinct * from books");}
else {
$sth1=$dbh->prepare($QueryString);
};
$sth1->execute();


$FileOfCurrentBook="";
@dataOfBook=();
$liststore->clear();

$switch->set_label("UNKNOW");

while(my @row=$sth1->fetchrow_array) {
push @dataOfBook, [decode("utf8",$row[1]),decode("utf8",$row[2]),decode("utf8",$row[3]),$row[4],$row[5],decode("utf8",$row[6]),$row[7]];
my $iter=$liststore->append();
	$liststore->set($iter,
	0=>$row[0],
	1=>decode("utf8",$row[1]),
	2=>decode("utf8",$row[2]),
	3=>decode("utf8",$row[3]),
	4=>decode("utf8",$row[4]),
	5=>$row[5],
	6=>decode("utf8",$row[6]),
	7=>$row[7],

	);
};
$labelPage->set_markup('');
$bufferBook->set_text("");
$QueryString="";
$image->clear();
};

sub open_response_cb {
my ($dialog, $response_id) = @_;
if ($response_id eq 'accept') {
	my $cur_dir = $dialog-> get_filename();
	@dataOfBook=();
	find(\&findfb2,$cur_dir);
};

$dialog->destroy();
#Write books into dataofbook massiv

for (my $i=0;$i<=$#dataOfBook;$i++){
	my $iter=$liststore->append();
	$liststore->set($iter,
	0=>"$i",
	1=>"$dataOfBook[$i][0]",
	2=>"$dataOfBook[$i][1]",
	3=>"$dataOfBook[$i][2]",
	4=>"$dataOfBook[$i][3]",
	5=>"$dataOfBook[$i][4]",
	6=>"$dataOfBook[$i][5]",
	);
#INSERT INTO DB data
#~ sqlite> create table books(Id INTAGER PRIMARY KEY, Author VARCHAR, Name VARCHAR, Genre VARCHAR, Year INTEGER(4), Read BOOLEAN, Filename Varchar);
my $sth=$dbh->prepare("insert into books (Author,Name,Genre,Year,Read,Filename) values(?,?,?,?,?,?)");
if ($add eq '1'){
my $string1=$dbh->quote($dataOfBook[$i][5]);
my $sth1=$dbh->prepare("select * from books where Filename=".$string1);
$sth1->execute();
my @rows=$sth1->fetchrow_array();
if ($#rows<0){
$sth->execute($dataOfBook[$i][0],$dataOfBook[$i][1],$dataOfBook[$i][2],
	$dataOfBook[$i][3],$dataOfBook[$i][4],$dataOfBook[$i][5]);	};
} else {
	$sth->execute($dataOfBook[$i][0],$dataOfBook[$i][1],$dataOfBook[$i][2],
	$dataOfBook[$i][3],$dataOfBook[$i][4],$dataOfBook[$i][5]);


};};

$QueryString=""; &ReadInfoBookFromDB();
}


sub findfb2{
return unless -f && $File::Find::name=~/\.fb2$/;
&read_fb2($File::Find::name);

}

sub read_fb2{
my ($filename_fb2) = @_;
my $parser=XML::LibXML->new();
#ПРОВЕРКА КОРРЕКТНОСТИ ФАЙЛА  -----ТЕСТИРОВАТЬ!!!!!!
#~ return if undef $parser;
	my $dom = $parser->parse_file($filename_fb2);
	my $title_info=($dom->getElementsByTagName('title-info'))[0];
	my $name_info=($title_info->getChildrenByTagName('book-title'))->to_literal;
	my $genre_info=($title_info->getChildrenByTagName('genre'))->to_literal;
	my $date_info=($title_info->getChildrenByTagName('date'))->to_literal;
	my $autor_info=($title_info->getChildrenByTagName('author'))[0];
	my $autorname_info=($autor_info->getChildrenByTagName('last-name'))->to_literal.
	" ".($autor_info->getChildrenByTagName('middle-name'))->to_literal.
	" ".($autor_info->getChildrenByTagName('first-name'))->to_literal;
	push @dataOfBook, [$autorname_info,$name_info,$genre_info,$date_info,"0",decode('utf8',$filename_fb2)];
}


sub treeselectionchanged{
return unless $QueryString eq "";
my ($select1)=@_;
my ($model,$iter)=$select1->get_selected();
if ($iter!=''){
	$NumberOfPage=1;
	$FileOfCurrentBook=$model->get_value($iter,6);
	if ($model->get_value($iter,5) eq '1')
	{
		$switch->set_label("Read");


	} else {$switch->set_label("Not Read");}
#~ print "Select $FileOfCurrentBook\n";
	&ReadInfoBook($FileOfCurrentBook);};
};


sub ReadInfoBook{
	my ($FileName)=@_;
	my $treeselection=$list_of_books->get_selection();
	my ($model,$iter)=$treeselection->get_selected();
	unless (-e $FileName){
	#Create message to delete file
	my $ConfirmDialogDelDromDb=Gtk3::MessageDialog->new(
        $window,
        [qw( modal destroy-with-parent )],
        'question',
        'yes-no',
        "File is not exist.\n Do you want DELETE this book from DB?"
            );

    if ('yes'  eq $ConfirmDialogDelDromDb->run) {
	my $string1=$dbh->quote($FileName);
	$dbh->do('delete from books where Filename='.$string1);

	if ($iter!=''){
	$liststore->remove($iter);
	}
	};
    $ConfirmDialogDelDromDb->destroy;
	return;
	};

	my $rating=$model->get($iter, 7);
	my $file_of_rating="Rate"."$rating".".png";
	$imageRate->set_from_file($file_of_rating);

	my $parser=XML::LibXML->new();
	my $dom = $parser->parse_file($FileName);
	my $title_info=($dom->getElementsByTagName('title-info'))[0];
	my $epigraph_info=($dom->getElementsByTagName('epigraph'))[0]->to_literal if ($dom->getElementsByTagName('epigraph'));
	my $annotation_info=($title_info->getChildrenByTagName('annotation'))->to_literal if ($dom->getElementsByTagName('annotation'));
	$bufferBook->set_text("");
	$bufferBook->insert_with_tags($bufferBook->get_start_iter(),"Аннотация \n\n",$tag_center,$tag_bold,$tag_backcolor);
	$bufferBook->insert_with_tags($bufferBook->get_end_iter(),$annotation_info,$tag_left);
	$bufferBook->insert_with_tags($bufferBook->get_end_iter(),"\n\nЭпиграф \n\n",$tag_center,$tag_bold,$tag_backcolor);
	$bufferBook->insert_with_tags($bufferBook->get_end_iter(),"$epigraph_info \n\n",$tag_left);
	$bufferBook->insert_with_tags($bufferBook->get_end_iter(),"Путь к файлу \n\n",$tag_center,$tag_bold,$tag_backcolor);
	$bufferBook->insert_with_tags($bufferBook->get_end_iter(),"$FileName",$tag_left);

my @binary_info=($dom->getElementsByTagName('binary'));
$MaxPages=$#binary_info+1;

if( defined ($binary_info[$NumberOfPage-1])){
my $image_format=(split /\// ,$binary_info[$NumberOfPage-1]->getAttribute("content-type"))[1];
my $name_of_pic=substr((split /\./, $binary_info[$NumberOfPage-1]->getAttribute('id'))[0],0,10);

$labelPage->set_markup("<b>$NumberOfPage</b> of <b>$MaxPages</b> - $name_of_pic");
my $image_blob=Image::Magick->new(magick=>$image_format);
$image_blob->BlobToImage(decode_base64($binary_info[$NumberOfPage-1]->to_literal));
my $width_new=$ScreenY-450;
my $height_new=$width_new;
if ($image_blob->Get('columns')>$image_blob->Get('rows')){
$height_new=$image_blob->Get('rows')*$width_new/$image_blob->Get('columns');
} else {	$width_new=$image_blob->Get('columns')*$height_new/$image_blob->Get('rows');}
$image_blob->Write('photo1');
$image_blob->Resize(height=>$height_new,width=>$width_new);
$image_blob->Write('photo.'.$image_format);
$image->set_from_file('photo.'.$image_format);
#~ $image_blob->Write('photo');
#~ $image->set_from_file('photo');
} else {
	$image->clear();
	$labelPage->set_markup("");};


}

sub onClickButtonNext{
	return if ($MaxPages<2);
	if ($NumberOfPage==$MaxPages){$NumberOfPage=0};
	$NumberOfPage++;
	$labelPage->set_markup("<b>$NumberOfPage</b> of <b>$MaxPages</b>");
	&ReadInfoBook($FileOfCurrentBook);
}

sub onClickButtonPrev {
	return if ($MaxPages<2);
	if ($NumberOfPage==1) {$NumberOfPage=$MaxPages+1};
	$NumberOfPage--;
	$labelPage->set_markup("<b>$NumberOfPage</b> of <b>$MaxPages</b>");
	&ReadInfoBook($FileOfCurrentBook);
}


sub onClickButtonDelete{
	return if $FileOfCurrentBook eq "";
	my $ConfirmDialogDelete=Gtk3::MessageDialog->new(
        $window,
        [qw( modal destroy-with-parent )],
        'question',
        'yes-no',
        "Do you want DELETE this file: \n $FileOfCurrentBook"
            );

    if ('yes'  eq $ConfirmDialogDelete->run) {
	my $string1=$dbh->quote($FileOfCurrentBook);
	$dbh->do('delete from books where Filename='.$string1);
	unlink $FileOfCurrentBook;
	my $treeselection=$list_of_books->get_selection();
	my ($model,$iter)=$treeselection->get_selected();
	if ($iter!=''){
	$liststore->remove($iter);
	}



		};
    $ConfirmDialogDelete->destroy;



}
sub onClickButtonOpen{
	return if $FileOfCurrentBook eq "";
	my $ConfirmDialogOpen=Gtk3::MessageDialog->new(
        $window,
        [qw( modal destroy-with-parent )],
        'question',
        'yes-no',
        "Do you want OPEN this file: \n $FileOfCurrentBook"
            );

    if ('yes'  eq $ConfirmDialogOpen->run) {
		if ($pid = fork) { $ConfirmDialogOpen->destroy; }
		else {
		defined($pid)|| die "fork: $!";
		exec 'fbreader' ,$FileOfCurrentBook;
		exit; # не дать по­ро­ж­ден­но­му про­цес­су вер­нуть­ся в ос­нов­ной код
		}



		};
    $ConfirmDialogOpen->destroy;



}

sub FindChange{

	my $FindString=$find->get_text();
	&ReadInfoBookFromDB($FindString);

}
