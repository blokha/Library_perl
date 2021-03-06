#!/usr/bin/perl

use Gtk3 -init;
use Glib qw/TRUE FALSE/;
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

my $dbh=DBI->connect("dbi:SQLite:dbname=Library_new.db","","") or die $_;

my $window = Gtk3::Window->new('toplevel');
$window->set_title('My Home Library');

my ($ScreenX,$ScreenY);
my @ScreenSize=`xrandr --current`;
($ScreenX,$ScreenY)= $ScreenSize[0]=~/current (\d+) x (\d+)/;
$window->set_default_size($ScreenX-180,$ScreenY-140);
print "Resolution $ScreenX x $ScreenY\n";
$window->set_position('center');
$window->set_border_width(10);
$window->signal_connect (delete_event => sub { Gtk3->main_quit });

my $find=Gtk3::Entry->new();
$find->signal_connect("activate",\&FindChange);

my @columns= ("Num","Autor","Name of Book","Genre","Year","Read","Filename","Rating");
my @dataOfBook;



my $liststore=Gtk3::ListStore->new('Glib::Int','Glib::String','Glib::String',
'Glib::String','Glib::String','Glib::Boolean','Glib::String','Glib::String');

my $list_of_books=Gtk3::TreeView->new($liststore);
for (my $i=0;$i<=$#columns;$i++){
	#Reads column
	if ($i==5){
	my $cell=Gtk3::CellRendererToggle->new();
	my $col=Gtk3::TreeViewColumn->new_with_attributes($columns[$i],$cell);
	$col->set("visible"=>FALSE);

	#~ $col->set_cell_data_func($cell, sub {
    #~ my ($column, $cell, $model, $iter) = @_;

    #~ if ($model->get($iter, 5)) {
        #~ $cell->set("active"=>"1");
    #~ } else {
        #~ $cell->set("active"=>"0");
    #~ }
#~ });

	$list_of_books->append_column($col); next;
	};
	#rate column
	if ($i==7){
		my $pixbuf;
		my $cell=Gtk3::CellRendererPixbuf->new();
		$cell->set("pixbuf"=>$pixbuf);
		my $col=Gtk3::TreeViewColumn->new_with_attributes($columns[$i],$cell);
		$col->set_sort_column_id($i);
			$col->set_cell_data_func($cell, sub {
				my ($column, $cell, $model, $iter) = @_;
				my $rating=$model->get($iter, 7);
				my $file_of_rating="Rate"."$rating".".png";
				$pixbuf=Gtk3::Gdk::Pixbuf->new_from_file_at_size($file_of_rating,100,20);
				$cell->set("pixbuf"=>$pixbuf);
				}
			);

		$list_of_books->append_column($col); next;
	}


	my $cell=Gtk3::CellRendererText->new();
	my $col=Gtk3::TreeViewColumn->new_with_attributes($columns[$i],$cell,'text'=>$i);
	$col->set("resizable"=>TRUE);
	$col->set_sort_column_id($i);
	$col->set_cell_data_func($cell, sub {
    my ($column, $cell, $model, $iter) = @_;
    if ($model->get($iter, 5)) {
        my $color=Gtk3::Gdk::color_parse('#8C881B');
        $cell->set('background-gdk' => $color);    } else {
        my $color=Gtk3::Gdk::color_parse('#F8F392');
        $cell->set('background-gdk' => $color);
        #~ ,Gtk3::Gdk::Color->new ("red"=>0,"green"=>0,"blue"=>65535)
    }
});
if ($i==0) {$col->set("visible"=>FALSE);}

	$list_of_books->append_column($col);

}



my $scrollwindowTreeBook=Gtk3::ScrolledWindow->new();
$scrollwindowTreeBook->set_min_content_height(190);
$scrollwindowTreeBook->set_policy('automatic','automatic');
$scrollwindowTreeBook->add($list_of_books);
$scrollwindowTreeBook->set_max_content_width(190);

my $treeselection=$list_of_books->get_selection();
$treeselection->signal_connect('changed',\&treeselectionchanged);
$list_of_books->signal_connect('row-activated',\&onClickButtonOpen);

my $image=Gtk3::Image->new();

my $imageRate=Gtk3::Image->new();
$imageRate->set_from_file("Rate.png");


my $event_box=Gtk3::EventBox->new();
$event_box->signal_connect('button-press-event',\&onMouseClickImageRate);
$event_box->add($imageRate);

my $event_box1=Gtk3::EventBox->new();
$event_box1->signal_connect('button-press-event',\&onMouseClickImage);
$event_box1->add($image);

#~ $imageRate->signal_connect('button-press-event',sub{print "Click"});

my $labelPage=Gtk3::Label->new();
$labelPage->set_markup('<b>1</b> of <b>1</b>');
$labelPage->set_justify('center');
$labelPage->set_line_wrap(FALSE);


my $textBook=Gtk3::TextView->new();
my $bufferBook=Gtk3::TextBuffer->new();
#Tags for textView
my $tag_bold=$bufferBook->create_tag("bold",weight=>'1000');
my $tag_center=$bufferBook->create_tag("center",justification=>'center');
my $tag_left=$bufferBook->create_tag("left",justification=>'left');
my $tag_backcolor=$bufferBook->create_tag("backcolor",background=>'yellow');

$textBook->set_buffer($bufferBook);
$textBook->set_wrap_mode('word');
$textBook->set_left_margin(20);
$textBook->set_right_margin(20);
$textBook->set_editable(FALSE);
$textBook->set_cursor_visible(FALSE);

my $scrollwindowTextBook=Gtk3::ScrolledWindow->new();
$scrollwindowTextBook->set_min_content_height($ScreenY-550);#  1050=>600
$scrollwindowTextBook->set_policy('automatic','automatic');
$scrollwindowTextBook->add($textBook);
#~ $scrollwindowTextBook->set_max_content_width(600);

my $ButtonRescan=Gtk3::Button->new();
$ButtonRescan->set_label('Rescan Library');
$ButtonRescan->set_relief('none');
$ButtonRescan->signal_connect('clicked',sub{$dbh->do("Delete from books");$liststore->clear();$add=0; &onClickButtonRescan;});

my $ButtonAdd=Gtk3::Button->new();
$ButtonAdd->set_label('Add new folder');
$ButtonAdd->set_relief('none');
$ButtonAdd->signal_connect('clicked',sub{$add=1;&onClickButtonRescan});

my $ButtonPrev=Gtk3::Button->new();
$ButtonPrev->set_label('Prev');
$ButtonPrev->set_relief('none');
$ButtonPrev->signal_connect('clicked',\&onClickButtonPrev);

my $ButtonNext=Gtk3::Button->new();
$ButtonNext->set_label('Next');
$ButtonNext->set_relief('none');
$ButtonNext->signal_connect('clicked',\&onClickButtonNext);

my $switch=Gtk3::Button->new_with_label("UNKNOW");
$switch->set_relief('none');
$switch->signal_connect('clicked',\&active_switch);

my $ButtonOpen=Gtk3::Button->new_with_label("Open file");
$ButtonOpen->set_relief('none');
$ButtonOpen->signal_connect('clicked',\&onClickButtonOpen);

my $ButtonDelete=Gtk3::Button->new_with_label("Delete file");
$ButtonDelete->set_relief('none');
$ButtonDelete->signal_connect('clicked',\&onClickButtonDelete);

my $hbox2=Gtk3::Box->new('horizontal',10);
$hbox2->pack_start($switch,TRUE,FALSE,5);
$hbox2->pack_start($ButtonOpen,TRUE,FALSE,5);
$hbox2->pack_start($ButtonDelete,TRUE,FALSE,5);
$hbox2->set_homogeneous(FALSE);
#~ gtk.STATE_NORMAL
	#~ State during normal operation.

#~ gtk.STATE_ACTIVE
	#~ State of a currently active widget, such as a depressed button.

#~ gtk.STATE_PRELIGHT
	#~ State indicating that the mouse pointer is over the widget and the widget will respond to mouse clicks.

#~ gtk.STATE_SELECTED
	#~ State of a selected item, such the selected row in a list.

#~ gtk.STATE_INSENSITIVE
	#~ State indicating that the widget is unresponsive to user actions.

$switch->modify_bg('normal',Gtk3::Gdk::Color->new ("red"=>0,"green"=>0,"blue"=>65535));
$switch->modify_fg('normal',Gtk3::Gdk::Color->new ("red"=>65000,"green"=>65535,"blue"=>65535));
my $color=Gtk3::Gdk::color_parse('#742A2A');
$switch->modify_fg('prelight',$color);

my $hboxbutton1=Gtk3::Box->new('horizontal',20);
$hboxbutton1->pack_start($ButtonPrev,TRUE,FALSE,30);
$hboxbutton1->pack_start($labelPage,TRUE,FALSE,30);
$hboxbutton1->pack_start($ButtonNext,TRUE,FALSE,30);
$hboxbutton1->set_homogeneous(TRUE);

my $hboxbuttonscan1=Gtk3::Box->new('horizontal',20);
$hboxbuttonscan1->pack_start($ButtonRescan,TRUE,FALSE,30);
$hboxbuttonscan1->pack_start($ButtonAdd,TRUE,FALSE,30);
$hboxbuttonscan1->set_homogeneous(FALSE);

my $grid=Gtk3::Grid->new();
$grid->set_row_spacing(20);
$grid->set_column_spacing(20);
$grid->set_column_homogeneous('true');
					#col,row,w,h
#0 row
$grid->attach($find,0,0,1,1);
$grid->attach($hbox2,1,0,1,1);
#1 row
$grid->attach($scrollwindowTreeBook,0,1,2,1);
#2 row
$grid->attach($scrollwindowTextBook,0,2,1,1);
$grid->attach($event_box1,1,2,1,2);
#3 row
$grid->attach($event_box,0,3,1,1);

#4 row
$grid->attach($hboxbuttonscan1,0,4,1,1);
$grid->attach($hboxbutton1,1,4,1,1);


$window->add($grid);
$window->show_all;
#ADD data DB from file
&ReadInfoBookFromDB();
Gtk3->main();

sub active_switch{
my $select1=$list_of_books->get_selection();
my ($model,$iter)=$select1->get_selected();
return unless $model;

my $read=1-$model->get_value($iter,5);
my $string1="update books set Read=$read where Id=".$model->get_value($iter,0);
$dbh->do($string1);

if ($model->get_value($iter,5) eq "1"){
$switch->set_label("Not Read");
$liststore->set($iter,5,"0");} else
{$liststore->set($iter,5,"1");
$switch->set_label("Read");
}
};
#Обработка рейтинга
sub onMouseClickImageRate {
	my $select1=$list_of_books->get_selection();
	my ($model,$iter)=$select1->get_selected();
	return unless $model;
	my ($widgent,$event)=@_;
	my $width1=($ScreenX-180)/2-20;
	my $x0=($width1-500)/2;
	my $first_x=(($event->x()-$x0)/100+1);
	my $rate=sprintf("%d",$first_x);
	$rate=5 if $rate>5;
	$rate=0 if $rate<0;
	$imageRate->set_from_file("Rate".$rate.".png");
	my $query_string="update books set read=1, rating=".$rate." where Id=".$model->get_value($iter,0);
	$dbh->do($query_string);
	$liststore->set($iter,7,$rate);
	$liststore->set($iter,5,"1");
}

sub onMouseClickImage {
	my ($widgent,$event)=@_;
	if (($event->type eq "2button-press")and ($event->button eq "1") and ($FileOfCurrentBook)){
		if ($pid = fork) {return 0;}
		else {
		defined($pid)|| die "fork: $!";
		exec 'xviewer' ,"photo1";
		exit;
		}
	};

}


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
