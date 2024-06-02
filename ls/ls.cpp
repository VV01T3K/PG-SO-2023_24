#include <dirent.h>
#include <grp.h>  // Include for getgrgid
#include <pwd.h>  // Include for getpwuid
#include <sys/stat.h>

#include <algorithm>
#include <cstring>
#include <ctime>
#include <iostream>
#include <vector>

using namespace std;

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
        }
        if (level > 0) {
            if (i == files.size() - 1) {
                cout << "└── ";
            } else {
                cout << "├── ";
            }
        }

        if (show_long) {
            cout << (S_ISDIR(s.st_mode) ? "d" : "-");
            cout << (s.st_mode & S_IRUSR ? "r" : "-");
            cout << (s.st_mode & S_IWUSR ? "w" : "-");
            cout << (s.st_mode & S_IXUSR ? "x" : "-");
            cout << (s.st_mode & S_IRGRP ? "r" : "-");
            cout << (s.st_mode & S_IWGRP ? "w" : "-");
            cout << (s.st_mode & S_IXGRP ? "x" : "-");
            cout << (s.st_mode & S_IROTH ? "r" : "-");
            cout << (s.st_mode & S_IWOTH ? "w" : "-");
            cout << (s.st_mode & S_IXOTH ? "x" : "-");
            cout << " ";
            cout << s.st_nlink << " ";
            cout << getpwuid(s.st_uid)->pw_name << " ";
            cout << getgrgid(s.st_gid)->gr_name << " ";
            cout << s.st_size << " ";
            std::string timeStr = ctime(&s.st_mtime);
            timeStr = timeStr.substr(0, timeStr.size() - 1);
            cout << timeStr;
            cout << " ";
        }

        if (show_blocks) cout << s.st_blocks / 2 << " ";
        cout << file;
        cout << endl;

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
    list_directory(directory, show_hidden, show_long, sort_by_time, show_blocks,
                   recursive);
    return 0;
}