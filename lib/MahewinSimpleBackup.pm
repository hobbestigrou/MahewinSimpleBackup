package MahewinSimpleBackup;

#ABSTRACT: A very simple backup tools

use Moose;

with 'MooseX::Getopt';

use File::Path qw(remove_tree);
use File::Spec;
use POSIX qw(strftime);

use Archive::Tar;
use Path::Class;
use Net::SCP;

has username => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => 'Username of the remote',
);

has host => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has directory_to_backup => (
    is       => 'ro',
    isa      => 'ArrayRef',
    required => 1,
    default  => sub { [] },
);

has directory_target => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has _scp => (
    is       => 'ro',
    isa      => 'Net::SCP',
    lazy     => 1,
    builder  => '_build_scp',
    init_arg => undef,
);

has _tar => (
    is       => 'ro',
    isa      => 'Archive::Tar',
    lazy     => 1,
    builder  => '_build_tar',
    init_arg => undef,
);

sub _build_scp {
    my ( $self ) = @_;

    Net::SCP->new({
        host => $self->host,
        user => $self->username,
    });
}

sub _build_tar {
    Archive::Tar->new;
}

sub run {
    my ( $self ) = @_;

       $self->_get_directory;
       $self->_archive;
}

sub _get_directory {
    my ( $self ) = @_;

    foreach my $dir (@{$self->directory_to_backup}) {
        $self->_scp->get($dir, $self->directory_target)
            or die $self->_scp->{errstr};
    }

    return;
}

sub _archive {
    my ( $self ) = @_;

    chdir($self->directory_target);

    my $now = strftime "%d-%m-%y-%H-%M", localtime;
    foreach my $dir (@{$self->directory_to_backup}) {
        my $rindex        = rindex($dir, '/');
        my $relative_path = substr($dir, $rindex + 1);

        if ( -d $relative_path ) {
            my $directory_object = Path::Class::Dir->new($relative_path);

            $directory_object->recurse( callback => sub {
                my ( $file ) = @_;

                if ( -f $file ) {
                    $self->_tar->add_files($file);
                }
            });
        }
        else {
            $self->_tar->add_files($relative_path);
        }

        remove_tree($relative_path);
    }

    $self->_tar->write("archives-$now.tar.gz", COMPRESS_GZIP);

    return;
}

1;
