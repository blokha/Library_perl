use Glib qw(TRUE FALSE);
use Gtk3 '-init';
use Gtk3::SimpleList;
 
my $slist = Gtk3::SimpleList->new (
              'Text Field'    => 'text',
              'Markup Field'  => 'markup',
              'Int Field'     => 'int',
              'Double Field'  => 'double',
              'Bool Field'    => 'bool',
              'Scalar Field'  => 'scalar',
              'Pixbuf Field'  => 'pixbuf',
            );
 
@{$slist->{data}} = (
        [ 'text', 1, 1.1,  TRUE, $var, $pixbuf ],
        [ 'text', 2, 2.2, FALSE, $var, $pixbuf ],
);
 
# (almost) anything you can do to an array you can do to 
# $slist->{data} which is an array reference tied to the list model
push @{$slist->{data}}, [ 'text', 3, 3.3, TRUE, $var, $pixbuf ];
 
# mess with selections
$slist->get_selection->set_mode ('multiple');
$slist->get_selection->unselect_all;
$slist->select (1, 3, 5..9); # select rows by index
$slist->unselect (3, 8); # unselect rows by index
@sel = $slist->get_selected_indices;
 
# simple way to make text columns editable
$slist->set_column_editable ($col_num, TRUE);
 
# Gtk3::SimpleList derives from Gtk3::TreeView, so all methods
# on a treeview are available.
$slist->set_rules_hint (TRUE);
$slist->signal_connect (row_activated => sub {
        my ($sl, $path, $column) = @_;
        my $row_ref = $sl->get_row_data_from_path ($path);
        # $row_ref is now an array ref to the double-clicked row's data.
    });
 
# turn an existing TreeView into a SimpleList; useful for
# Glade-generated interfaces.
$simplelist = Gtk3::SimpleList->new_from_treeview (
                  $glade->get_widget ('treeview'),
                  'Text Field'    => 'text',
                  'Int Field'     => 'int',
                  'Double Field'  => 'double',
               );
