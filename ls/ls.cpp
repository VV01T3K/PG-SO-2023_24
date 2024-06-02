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

void list_directory(const string& path, bool show_hidden, bool show_long,
                    bool sort_by_time, bool show_blocks, bool recursive,
                    int level = 0) {
    DIR* dir = opendir(path.c_str());
    if (dir == NULL) {
        cout << "Cannot open directory: " << path << endl;
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

        // Print indentation
        for (int j = 0; j < level; j++) {
            cout << "│   ";
            if (show_blocks) printf("    ");
        }
        if (i == files.size() - 1) {
            cout << "└── ";
        } else {
            cout << "├── ";
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

        printf("\n");

        if (S_ISDIR(s.st_mode) && file != "." && file != ".." && recursive)
            list_directory(full_path, show_hidden, show_long, sort_by_time,
                           show_blocks, recursive, level + 1);
    }

    return;
}

int main(int argc, char* argv[]) {
    bool show_hidden = false;
    bool show_long = false;
    bool sort_by_time = false;
    bool show_blocks = false;
    bool recursive = false;
    string directory = ".";

    for (int i = 1; i < argc; i++) {
        if (argv[i][0] == '-') {
            for (int j = 1; argv[i][j] != '\0'; j++) {
                switch (argv[i][j]) {
                    case 'a':
                        show_hidden = true;
                        break;
                    case 'l':
                        show_long = true;
                        break;
                    case 't':
                        sort_by_time = true;
                        break;
                    case 's':
                        show_blocks = true;
                        break;
                    case 'R':
                        recursive = true;
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

    printf("total %ld\n", count_blocks(directory, show_hidden));
    printf("\033[34m%s\033[0m\n", directory.c_str());
    list_directory(directory, show_hidden, show_long, sort_by_time, show_blocks,
                   recursive);
    return 0;
}