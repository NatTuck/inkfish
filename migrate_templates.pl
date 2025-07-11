#!/usr/bin/env perl

use strict;
use warnings;
use File::Find;
use File::Path qw(make_path);
use File::Copy qw(move);
use File::Basename qw(dirname basename);
use File::Spec::Functions qw(catfile splitdir);
use Cwd qw(abs_path);

# --- Configuration ---
# Base directory for templates (source)
my $templates_dir = 'lib/inkfish_web/templates';
# Base directory for controllers (destination)
my $controllers_dir = 'lib/inkfish_web/controllers';
# The base module name for your web application
my $web_module = 'InkfishWeb';
# --- End Configuration ---

# Keep track of which HTML modules we've already created to avoid duplication
my %created_html_modules;

# Safety check: ensure the script is run from the project root
die "Error: Please run this script from the root of your Phoenix project.\n" .
    "Could not find '$templates_dir' or '$controllers_dir' in the current directory.\n"
    unless -d $templates_dir && -d $controllers_dir;

print "Starting template migration from '$templates_dir' to '$controllers_dir'...\n";

# Find all files in the templates directory and process them
find(\&process_template, $templates_dir);

# Clean up empty directories left behind in the templates folder
print "Cleaning up empty directories in '$templates_dir'...\n";
finddepth(
    sub {
        my $path = $File::Find::name;
        # rmdir is safe; it will not remove non-empty directories
        rmdir $path if -d $path && $path ne $templates_dir;
    },
    $templates_dir
);

print "Migration script finished successfully.\n";

# This subroutine is called by File::Find for each file found.
sub process_template {
    # The full path to the current file is in $_
    # and also in $File::Find::name
    my $template_file_path = $File::Find::name;

    # We only care about .html.eex files
    return unless $template_file_path =~ /\.html\.eex$/;

    print "\nProcessing: $template_file_path\n";

    # 1. Deconstruct the old path and construct the new paths
    my $relative_path_full = $template_file_path;
    $relative_path_full =~ s/^$templates_dir\///; # e.g., "admin/course/edit.html.eex"

    my $template_basename = basename($relative_path_full); # e.g., "edit.html.eex"
    my $template_subdir   = dirname($relative_path_full);  # e.g., "admin/course"

    # New template path, e.g., lib/inkfish_web/controllers/admin/course_html/edit.html.heex
    my $new_template_dir = catfile($controllers_dir, "${template_subdir}_html");
    my $new_template_filename = $template_basename;
    $new_template_filename =~ s/\.html\.eex$/.html.heex/;
    my $new_template_path = catfile($new_template_dir, $new_template_filename);

    # Path for the corresponding *_html.ex file
    # e.g., lib/inkfish_web/controllers/admin/course_html.ex
    my @path_parts = splitdir($template_subdir);
    my $controller_name_part = pop @path_parts;
    my $html_module_dir = catfile($controllers_dir, @path_parts);
    my $html_module_path = catfile($html_module_dir, "${controller_name_part}_html.ex");

    # 2. Create the destination directory for the template
    make_path($new_template_dir) or die "Failed to create directory '$new_template_dir': $!";

    # 3. Move and rename the template file
    print "  -> Moving to $new_template_path\n";
    move($template_file_path, $new_template_path)
        or die "Failed to move '$template_file_path' to '$new_template_path': $!";

    # Skip if we've already created this HTML module file for this controller
    return if $created_html_modules{$html_module_path};

    # 4. Construct the Elixir module name from the path
    my @module_name_parts = split('/', $template_subdir);
    my @camel_cased_parts;
    foreach my $part (@module_name_parts) {
        # Converts snake_case to CamelCase (e.g., "user_session" -> "UserSession")
        my $camel = join("", map { ucfirst lc } split('_', $part));
        push @camel_cased_parts, $camel;
    }
    my $module_name = $web_module . "." . join(".", @camel_cased_parts) . "HTML";

    # 5. Generate the boilerplate content for the *_html.ex file
    my $html_module_content = <<"EOF";
defmodule $module_name do
  use $web_module, :html

  embed_templates "#{@controller_name_part}_html/*"
end
EOF

    # 6. Create the new *_html.ex file
    print "  -> Creating new view module: $html_module_path\n";
    open(my $fh, '>', $html_module_path)
        or die "Could not open file '$html_module_path' for writing: $!";
    print $fh $html_module_content;
    close $fh;

    # Mark this module as created so we don't create it again
    $created_html_modules{$html_module_path} = 1;
}
