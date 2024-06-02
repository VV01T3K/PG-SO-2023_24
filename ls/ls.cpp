#include <dirent.h>
#include <grp.h>
#include <pwd.h>
#include <sys/stat.h>
#include <unistd.h>

#include <algorithm>
#include <cstring>
#include <ctime>
#include <iostream>
#include <vector>

using namespace std;

/**
 * The function `count_blocks` calculates the total number of blocks used by
 * files in a directory, excluding hidden files based on the `show_hidden`
 * parameter.
 *
 * @param path The `path` parameter is a string that represents the directory
 * path for which you want to count the blocks.
 * @param show_hidden The `show_hidden` parameter is a boolean flag that
 * determines whether hidden files and directories should be included in the
 * count. If `show_hidden` is set to true, all files and directories, including
 * those whose names start with a dot (.), will be counted. If `show_hidden` is
 * set
 *
 * @return The function `count_blocks` returns the total number of blocks used
 * by the files in the specified directory `path`, divided by 2.
 */
long count_blocks(const string& path, bool show_hidden) {
    DIR* dir = opendir(path.c_str());
    if (dir == NULL) {
        cout << "Cannot open directory: " << path << endl;
        return 0;
    }

    long total_blocks = 0;
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (!show_hidden && entry->d_name[0] == '.') continue;
        struct stat s;
        stat((path + "/" + entry->d_name).c_str(), &s);
        total_blocks += s.st_blocks;
    }
    closedir(dir);

    return total_blocks / 2;
}

/**
 * The function `list_directory` recursively lists files and directories in a
 * given path with various display options.
 *
 * @param path The `path` parameter is a string that represents the directory
 * path for which you want to list the contents.
 * @param show_hidden The `show_hidden` parameter in the `list_directory`
 * function determines whether hidden files (files starting with a dot) should
 * be displayed or not. If `show_hidden` is set to `true`, hidden files will be
 * included in the list of files to be displayed. If set to `false
 * @param show_long The `show_long` parameter in the `list_directory` function
 * determines whether to display detailed information about each file in the
 * directory. If `show_long` is set to `true`, the function will display file
 * permissions, owner, group, size, and modification time in addition to the
 * file name.
 * @param sort_by_time The `sort_by_time` parameter in the `list_directory`
 * function determines whether the files in the directory should be sorted by
 * their modification time. If `sort_by_time` is set to `true`, the files will
 * be sorted in descending order based on their modification time. If it's set
 * to
 * @param show_blocks The `show_blocks` parameter in the `list_directory`
 * function determines whether to display the number of 512-byte blocks
 * allocated to the file. If `show_blocks` is set to `true`, the function will
 * display the number of blocks allocated for each file in the directory
 * listing. If `show
 * @param recursive The `recursive` parameter in the `list_directory` function
 * determines whether the function should recursively list the contents of
 * subdirectories. If `recursive` is set to `true`, the function will continue
 * to list the contents of subdirectories within the specified directory. If
 * `recursive` is set to `false
 * @param one_per_line The `one_per_line` parameter in the `list_directory`
 * function is a boolean flag that determines whether each file or directory
 * entry should be displayed on a separate line. If `one_per_line` is set to
 * `true`, each entry will be printed on a new line. If it is set
 * @param level The `level` parameter in the `list_directory` function is used
 * to keep track of the depth of recursion when listing directories. It starts
 * at 0 for the initial directory and increments by 1 for each level of
 * recursion into subdirectories. This parameter helps in formatting the output
 * to display a visual
 *
 * @return The function `list_directory` is returning `void`, which means it
 * does not return any value.
 */
void list_directory(const string& path, bool show_hidden, bool show_long,
                    bool sort_by_time, bool show_blocks, bool recursive,
                    bool one_per_line, int level = 0) {
    DIR* dir = opendir(path.c_str());
    if (dir == NULL) {
        cout << "Cannot open directory: " << path;
        return;
    }

    vector<string> files;
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (!show_hidden && entry->d_name[0] == '.') continue;
        files.push_back(entry->d_name);
    }
    closedir(dir);

    if (sort_by_time) {
        sort(files.begin(), files.end(), [&](const string& a, const string& b) {
            struct stat sa, sb;
            stat((path + "/" + a).c_str(), &sa);
            stat((path + "/" + b).c_str(), &sb);
            return sa.st_mtime > sb.st_mtime;
        });
    } else {
        sort(files.begin(), files.end());
    }

    for (size_t i = 0; i < files.size(); i++) {
        const string& file = files[i];
        string full_path = path + "/" + file;
        struct stat s;
        stat(full_path.c_str(), &s);

        if (show_long || one_per_line) {
            for (int j = 0; j < level; j++) {
                cout << "│   ";
                if (show_blocks) printf("    ");
            }
            if (i == files.size() - 1) {
                cout << "└── ";
            } else {
                cout << "├── ";
            }
        }

        if (show_blocks) printf("%4ld ", s.st_blocks / 2);

        if (show_long) {
            printf("%c%c%c%c%c%c%c%c%c%c %4ld %8s %8s %8ld %.24s ",
                   S_ISDIR(s.st_mode) ? 'd' : '-',
                   s.st_mode & S_IRUSR ? 'r' : '-',
                   s.st_mode & S_IWUSR ? 'w' : '-',
                   s.st_mode & S_IXUSR ? 'x' : '-',
                   s.st_mode & S_IRGRP ? 'r' : '-',
                   s.st_mode & S_IWGRP ? 'w' : '-',
                   s.st_mode & S_IXGRP ? 'x' : '-',
                   s.st_mode & S_IROTH ? 'r' : '-',
                   s.st_mode & S_IWOTH ? 'w' : '-',
                   s.st_mode & S_IXOTH ? 'x' : '-', s.st_nlink,
                   getpwuid(s.st_uid)->pw_name, getgrgid(s.st_gid)->gr_name,
                   s.st_size, ctime(&s.st_mtime));
        }

        if (isatty(STDOUT_FILENO)) {
            if (S_ISDIR(s.st_mode)) {
                cout << "\033[1;34m" << file << "\033[0m";
            } else if (s.st_mode & S_IXUSR || s.st_mode & S_IXGRP ||
                       s.st_mode & S_IXOTH) {
                cout << "\033[1;32m" << file << "\033[0m";
            } else {
                cout << file;
            }
        } else {
            cout << file;
        }

        if (one_per_line || show_long) {
            cout << endl;
        } else {
            cout << "  ";
        }

        if (S_ISDIR(s.st_mode) && file != "." && file != ".." && recursive)
            list_directory(full_path, show_hidden, show_long, sort_by_time,
                           show_blocks, recursive, level + 1);
    }

    return;
}

/**
 * The main function processes command line arguments to display directory
 * contents with various options.
 *
 * @param argc The `argc` parameter in the `main` function represents the number
 * of arguments passed to the program when it is executed, including the name of
 * the program itself.
 * @param argv The `argv` parameter in the `main` function is an array of
 * C-style strings (char arrays) that represent the command-line arguments
 * passed to the program when it is executed. The first element `argv[0]`
 * typically contains the name of the program being executed, and subsequent
 * elements contain
 *
 * @return The `main` function is returning an integer value, specifically `0`
 * if the program runs successfully without any errors. If there is an error in
 * processing the command line arguments, the function will return `1`.
 */
int main(int argc, char* argv[]) {
    bool show_hidden = false;
    bool show_long = false;
    bool sort_by_time = false;
    bool show_blocks = false;
    bool recursive = false;
    bool one_per_line = false;
    string directory = ".";

    for (int i = 1; i < argc; i++) {
        if (argv[i][0] == '-') {
            for (int j = 1; argv[i][j] != '\0'; j++) {
                switch (argv[i][j]) {
                    case 'l':
                        show_long = true;
                        break;
                    case 'R':
                        recursive = true;
                        break;
                    case 'a':
                        show_hidden = true;
                        break;
                    case 't':
                        sort_by_time = true;
                        break;
                    case 's':
                        show_blocks = true;
                        break;
                    case '1':
                        one_per_line = true;
                        break;
                    default:
                        cout << "Invalid option: " << argv[i][j] << endl;
                        return 1;
                }
            }
        } else {
            directory = argv[i];
        }
    }

    if (show_long) printf("total %ld\n", count_blocks(directory, show_hidden));
    if (show_long || one_per_line || recursive)
        printf("\033[34m%s\033[0m\n", directory.c_str());
    list_directory(directory, show_hidden, show_long, sort_by_time, show_blocks,
                   recursive, one_per_line);
    if (!(show_long || one_per_line)) printf("\n");
    return 0;
}