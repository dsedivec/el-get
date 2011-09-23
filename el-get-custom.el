;;; el-get-recipes.el --- Manage the external elisp bits and pieces you depend upon
;;
;; Copyright (C) 2010-2011 Dimitri Fontaine
;;
;; Author: Dimitri Fontaine <dim@tapoueh.org>
;; URL: http://www.emacswiki.org/emacs/el-get
;; GIT: https://github.com/dimitri/el-get
;; Licence: WTFPL, grab your copy here: http://sam.zoy.org/wtfpl/
;;
;; This file is NOT part of GNU Emacs.
;;
;; Install
;;     Please see the README.asciidoc file from the same distribution

;;; Commentary:
;;
;; el-get-recipes provides the API to manage the el-get recipes.
;;

;; el-get-core provides basic el-get API, intended for developpers of el-get
;; and its methods.  See the methods directory for implementation of them.
;;

(require 'el-get-core)

;;; "Fuzzy" data structure customization widgets
(defun el-get-repeat-value-to-internal (widget element-or-list)
  (el-get-as-list element-or-list))

(defun el-get-repeat-match (widget value)
  (widget-editable-list-match widget (el-get-repeat-value-to-internal widget value)))

(define-widget 'el-get-repeat 'repeat
  "A variable length list of non-lists that can also be represented as a single element"
  :value-to-internal 'el-get-repeat-value-to-internal
  :match 'el-get-repeat-match)

(defun el-get-symbol-match (widget value)
  (or (symbolp value) (stringp value)))

(define-widget 'el-get-symbol 'symbol
  "A string or a symbol, rendered as a symbol"
  :match 'el-get-symbol-match
)
;;; END "Fuzzy" data structure support

(defun el-get-source-name (source)
  "Return the package name (stringp) given an `el-get-sources'
entry."
  (if (symbolp source) (symbol-name source)
    (format "%s" (plist-get source :name))))


(defconst el-get-build-recipe-body
  '(choice :tag "Format"

           (repeat :tag "List of shell commands"
                    (string :doc "Note: arguments will not be shell-quoted.
Choose `Evaluated expression' format for a more portable recipe" :format "%v%h"))
           (sexp :tag "Evaluated expression" :format "%t: %v%h"
                 :value `(("./configure" ,(concat "--with-emacs=" el-get-emacs)) ("make") ("make" ("install")))

                 :doc "Evaluation should yield a list of lists.
Each sub-list, representing a single shell command, is expected to have
strings and/or lists as elements, sub-sub-lists can have string and/or
list elements, and so on.  Each sub-list will be \"flattened\" to produce
a list of strings, each of which will be `shell-quote-argument'ed before
being sent to the underlying shell."
                 )
           ))


(defcustom el-get-sources nil
  "Additional package recipes

Each entry is a PLIST where the following properties are
supported.

If your property list is missing the :type property, then it's
merged with the recipe one, so that you can override any
definition provided by `el-get' recipes locally.

:name

    The name of the package. It can be different from the name of
    the directory where the package is stored (after a `git
    clone' for example, in which case a symlink will be created.

:depends

    A single package name, or a list of package names, on which
    the package depends.  All of a packages dependencies will be
    installed before the package is installed.

:pkgname

    The name of the package for the underlying package management
    system (`apt-get', `fink' or `pacman', also supported by
    `emacsmirror'), which can be different from the Emacs package
    name.

:type

    The type of the package, currently el-get offers support for
    `apt-get', `elpa', `git', `emacsmirror', `git-svn', `bzr' `svn',
    `cvs', `darcs', `fink', `ftp', `emacswiki', `http-tar', `pacman',
    `hg' and `http'. You can easily support your own types here, 
    see the variable `el-get-methods'.

:branch

    Which branch to fetch when using `git'.  Also supported in
    the installer in `el-get-install'.

:url

    Where to fetch the package, only meaningful for `git' and `http' types.

:build

    Your build recipe, a list.

    A recipe R whose `car' is not a string will be replaced
    by (eval R).

    Then, each element of the recipe will be interpreted as
    a command:

    * If the element is a string, it will be interpreted directly
      by the shell.

    * Otherwise, if it is a list, any list sub-elements will be
      recursively \"flattened\" (see `el-get-flatten').  The
      resulting strings will be interpreted as individual shell
      arguments, appropriately quoted.

:build/system-type

    Your specific build recipe for a given `system-type' gets
    there and looks like :build.

:load-path

    A directory or a list of directories you want `el-get' to add
    to your `load-path'. Those directories are relative to where
    the package gets installed.

:compile

    Allow to restrict what to byte-compile: by default, `el-get'
    will compile all elisp files in the :load-path directories,
    unless a :build command exists for the package source. Given
    a :compile property, `el-get' will only byte-compile those
    given files, directories or filename-regexpes in the property
    value. This property can be a `listp' or a `stringp' if you
    want to compile only one of those.

:info

    This string allows you to setup a directory where to find a
    'package.info' file, or a path/to/whatever.info file. It will
    even run `ginstall-info' for you to create the `dir' entry so
    that C-h i will be able to list the newly installed
    documentation. Note that you might need to kill (C-x k) your
    info buffer then C-h i again to be able to see the new menu
    entry.

:load

    List of files to load, or a single file to load after having
    installed the source but before `require'ing its features.

:features

    List of features el-get will `require' for you.

:autoloads

    Control whether el-get should generate autoloads for this
    package. Setting this to nil prevents el-get from generating
    autoloads for the package. Default is t. Setting this to a
    string or a list of string will load the named autoload
    files.

:library

    When using :after but not using :features, :library allows to
    set the library against which to register the :after function
    against `eval-after-load'.  It defaults to either :pkgname
    or :package, in this order.  See also `el-get-eval-after-load'.

:options

    Currently used by http-tar and cvs support.

    When using http-tar, it allows you to give the tar options
    you want to use. Typically would be \"xzf\", but you might
    want to choose \"xjf\" for handling .tar.bz files e.g.

    When using CVS, when it's set to \"login\", `el-get' will
    first issue a `cvs login' against the server, asking you
    interactively (in the minibuffer) any password you might to
    enter, and only then it will run the `cvs checkout' command.

:module

    Currently only used by the `cvs' support, allow you to
    configure the module you want to checkout in the given URL.

:repo

    Only used by the `elpa' support, a cons cell with the
    form (NAME . URL), as in `package-archives'.  If the package
    source only specifies a URL, the URL will be used for NAME as
    well.

:prepare

    Intended for use from recipes, it will run once both the
    `Info-directory-list' and the `load-path' variables have been
    taken care of, but before any further action from
    `el-get-init'.

:before

    A pre-init function to run once before `el-get-init' calls
    `load' and `require'.  It gets to run with `load-path'
    already set, and after :prepare has been called.  It's not
    intended for use from recipes.

:post-init

    Intended for use from recipes.  This function is registered
    for `eval-after-load' against the recipe library by
    `el-get-init' once the :load and :features have been setup.

:after

    A function to register for `eval-after-load' against the
    recipe library, after :post-init, and after per-package
    user-init-file (see `el-get-user-package-directory').  That's not
    intended for recipe use.

:lazy

    Default to nil.  Allows to override `el-get-is-lazy' per
    package.

:localname

    Currently only used by both `http' and `ftp' supports, allows
    to specify the target name of the downloaded file.

    This option is useful if the package should be retrieved using
    a presentation interface (such as as web SCM tool).

    For example, destination should be set to \"package.el\" if
    the package url has the following scheme:

   \"http://www.example.com/show-as-text?file=path/package.el\"

:website

    The website of the project.

:description

    A short description of the project.

"

  :type
  `(repeat
    (choice
     :tag "Entry"
     :value (:name "")
     (el-get-symbol :tag "Name of EL-Get Package")
     (list
      :tag "Full Recipe (or Recipe Override)"
      (group :inline t :tag "EL-Get Package Name" :format "%t: %v"
             (const :format "" :name) (el-get-symbol :format "%v"))
      (set
       :inline t :format "%v\n"
       (group
        :inline t  (const :format "" :depends)
        (el-get-repeat
         :tag "Names of packages on which this one depends" el-get-symbol))
       (group
        :inline t :format "%t: %v%h"
        :tag "Underlying Package Name"
        :doc "When there is an underlying package manager (e.g. `apt')
this is the name to fetch in that system"
        (const :format "" :pkgname) (string :format "%v"))

       (group
        :inline t :tag "Type" :format "%t: %v%h"
        :doc "(If omitted, this recipe provides overrides for one in recipes/)"
        (const :format "" :type)
        ,(append '(choice :value emacswiki :format "%[Value Menu%] %v"
                          )
                 ;; A sorted list of method names
                 (sort
                  (reduce
                   (lambda (r e)
                     (if (symbolp e)
                         (cons
                          (list 'const
                                (intern (substring (prin1-to-string e) 1)))
                          r)
                       r))
                   el-get-methods
                   :initial-value nil)
                  (lambda (x y)
                    (string< (prin1-to-string (cadr x))
                             (prin1-to-string (cadr y)))))))

       (group :inline t :format "Source URL: %v"
              (const :format "" :url) (string :format "%v"))
       (group :inline t :format "Package Website: %v"
              (const :format "" :website) (string :format "%v"))
       (group :inline t :format "Description: %v"
              (const :format "" :description) (string :format "%v"))
       (group :inline t :format "General Build Recipe\n%v"
              (const :format "" :build) ,el-get-build-recipe-body)
       (group :inline t  (const :format "" :load-path)
              (el-get-repeat
               :tag "Subdirectories to add to load-path" directory))
       (group :inline t  (const :format "" :compile)
              (el-get-repeat
               :tag "File/directory regexps to compile" regexp))
       (group :inline t :format "%v" (const :format "" :info)
              (string :tag "Path to .info file or to its directory"))
       (group :inline t (const :format "" :load)
              (el-get-repeat :tag "Relative paths to force-load" string))
       (group :inline t :format "%v" (const :format "" :features)
              (repeat :tag "Features to `require'" el-get-symbol))
       (group :inline t :format "Autoloads: %v" :value (:autoloads t)
              (const :format "" :autoloads)
              (choice
               :tag "Type"
               (boolean :format "generation %[Toggle%] %v\n")
               (el-get-repeat
                :tag "Relative paths to force-load" string)))
       (group :inline t :format "Options (`http-tar' and `cvs' only): %v"
              (const :format "" :options) (string :format "%v"))
       (group :inline t :format "CVS Module: %v"
              (const :format "" :module)
              (string :format "%v"))
       (group :inline t :format "`Prepare' Function: %v"
              (const :format "" :prepare) (function :format "%v"))
       (group :inline t :format "`Post-Init' Function: %v"
              (const :format "" :post-init) (function :format "%v"))
       (group :inline t
              :format "Name of downloaded file (`http' and `ftp' only): %v"
              (const :format "" :localname) (string :format "%v"))
       (group :inline t :format "Lazy: %v"  :value (:lazy t)
              (const :format "" :lazy) (boolean :format "%[Toggle%] %v\n"))
       (group :inline t
              :format "Repository specification (`elpa' only): %v"
              (const :format "" :repo)
              (cons :format "\n%v"
                    (string :tag "Name")
                    (string :tag "URL")))
       (group :inline t
              :format "`Before' Function (`Prepare' recommended instead): %v"
              (const :format "" :before) (function :format "%v"))
       (group :inline t
              :format "`After' Function (`Post-Init' recommended instead): %v"
              (const :format "" :after) (function :format "%v")))
      (repeat
       :inline t :tag "System-Specific Build Recipes"
       (group :inline t
              (symbol :value ,(concat ":build/"
                                      (prin1-to-string system-type))
                      :format "Build Tag: %v%h"
                      :doc "Must be of the form `:build/<system-type>',
where `<system-type>' is the value of `system-type' on
platforms where this recipe should apply"
                      )
              ,el-get-build-recipe-body))))))

(provide 'el-get-custom)
