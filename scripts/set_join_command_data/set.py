import sys

init_log_file_path = sys.argv[1]
env_file_path = sys.argv[2]


def get_join_command_data() -> tuple:
    token_data = ''
    hash_string_data = ''

    with open(init_log_file_path, 'r', encoding='utf-8') as file:
        lines = file.readlines()
        for line in lines:
            if '--token' in line:
                token_data = line.split('--token')[1].split(' \\')[0].strip()
            if '--discovery-token-ca-cert-hash' in line:
                hash_string_data = line.split('--discovery-token-ca-cert-hash')[1].strip()

    return token_data, hash_string_data


def set_env_vars(token: str, hash_string: str) -> None:
    lines = []

    with open(env_file_path, 'r', encoding='utf-8') as file:
        lines = file.readlines()

    with open(env_file_path, 'w', encoding='utf-8') as file:
        for line in lines:
            if 'JOIN_TOKEN=' not in line and 'JOIN_HASH=' not in line:
                file.write(line)

    with open(env_file_path, 'a', encoding='utf-8') as file:
        file.write(f'\nJOIN_TOKEN={token}\n')
        file.write(f'JOIN_HASH={hash_string}\n')


if __name__ == "__main__":
    token_data, hash_string_data = get_join_command_data()
    set_env_vars(token_data, hash_string_data)
