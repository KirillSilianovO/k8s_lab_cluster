import crypt
import sys

password = sys.argv[1]
env_file_path = sys.argv[2]


def set_env_vars() -> None:
    hash_string = crypt.crypt(password, crypt.mksalt(crypt.METHOD_SHA512))

    lines = []

    with open(env_file_path, 'r', encoding='utf-8') as file:
        lines = file.readlines()

    with open(env_file_path, 'w', encoding='utf-8') as file:
        for line in lines:
            if 'NODE_PASSWORD_HASH=' not in line:
                file.write(line)

    with open(env_file_path, 'a', encoding='utf-8') as file:
        file.write(f'NODE_PASSWORD_HASH={hash_string}\n')


if __name__ == "__main__":
    set_env_vars()
