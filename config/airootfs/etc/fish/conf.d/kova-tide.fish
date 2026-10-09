# Kova Tide defaults: adapted from the user's existing Tide v6 Lean prompt.
# No tide configure: Fish universal variables are shared with Tide's asynchronous
# prompt subprocesses and persist per user. Never overwrite existing user values.
# The full tide_pwd_markers and tide_right_prompt_items lists were verified
# against the original Fish universal-variable configuration.
function __kova_tide_defaults
    if not set -q tide_aws_bg_color
        set -U tide_aws_bg_color 'normal'
    end
    if not set -q tide_aws_color
        set -U tide_aws_color 'FF9900'
    end
    if not set -q tide_aws_icon
        set -U tide_aws_icon ''
    end
    if not set -q tide_character_color
        set -U tide_character_color '5FD700'
    end
    if not set -q tide_character_color_failure
        set -U tide_character_color_failure 'FF0000'
    end
    if not set -q tide_character_icon
        set -U tide_character_icon '❯'
    end
    if not set -q tide_character_vi_icon_default
        set -U tide_character_vi_icon_default '❮'
    end
    if not set -q tide_character_vi_icon_replace
        set -U tide_character_vi_icon_replace '▶'
    end
    if not set -q tide_character_vi_icon_visual
        set -U tide_character_vi_icon_visual 'V'
    end
    if not set -q tide_cmd_duration_bg_color
        set -U tide_cmd_duration_bg_color 'normal'
    end
    if not set -q tide_cmd_duration_color
        set -U tide_cmd_duration_color '87875F'
    end
    if not set -q tide_cmd_duration_decimals
        set -U tide_cmd_duration_decimals '0'
    end
    if not set -q tide_cmd_duration_icon
        set -U tide_cmd_duration_icon ''
    end
    if not set -q tide_cmd_duration_threshold
        set -U tide_cmd_duration_threshold '3000'
    end
    if not set -q tide_context_always_display
        set -U tide_context_always_display 'false'
    end
    if not set -q tide_context_bg_color
        set -U tide_context_bg_color 'normal'
    end
    if not set -q tide_context_color_default
        set -U tide_context_color_default 'D7AF87'
    end
    if not set -q tide_context_color_root
        set -U tide_context_color_root 'D7AF00'
    end
    if not set -q tide_context_color_ssh
        set -U tide_context_color_ssh 'D7AF87'
    end
    if not set -q tide_context_hostname_parts
        set -U tide_context_hostname_parts '1'
    end
    if not set -q tide_crystal_bg_color
        set -U tide_crystal_bg_color 'normal'
    end
    if not set -q tide_crystal_color
        set -U tide_crystal_color 'FFFFFF'
    end
    if not set -q tide_crystal_icon
        set -U tide_crystal_icon ''
    end
    if not set -q tide_direnv_bg_color
        set -U tide_direnv_bg_color 'normal'
    end
    if not set -q tide_direnv_bg_color_denied
        set -U tide_direnv_bg_color_denied 'normal'
    end
    if not set -q tide_direnv_color
        set -U tide_direnv_color 'D7AF00'
    end
    if not set -q tide_direnv_color_denied
        set -U tide_direnv_color_denied 'FF0000'
    end
    if not set -q tide_direnv_icon
        set -U tide_direnv_icon '▼'
    end
    if not set -q tide_distrobox_bg_color
        set -U tide_distrobox_bg_color 'normal'
    end
    if not set -q tide_distrobox_color
        set -U tide_distrobox_color 'FF00FF'
    end
    if not set -q tide_distrobox_icon
        set -U tide_distrobox_icon '󰆧'
    end
    if not set -q tide_docker_bg_color
        set -U tide_docker_bg_color 'normal'
    end
    if not set -q tide_docker_color
        set -U tide_docker_color '2496ED'
    end
    if not set -q tide_docker_default_contexts
        set -U tide_docker_default_contexts 'default' 'colima'
    end
    if not set -q tide_docker_icon
        set -U tide_docker_icon ''
    end
    if not set -q tide_elixir_bg_color
        set -U tide_elixir_bg_color 'normal'
    end
    if not set -q tide_elixir_color
        set -U tide_elixir_color '4E2A8E'
    end
    if not set -q tide_elixir_icon
        set -U tide_elixir_icon ''
    end
    if not set -q tide_gcloud_bg_color
        set -U tide_gcloud_bg_color 'normal'
    end
    if not set -q tide_gcloud_color
        set -U tide_gcloud_color '4285F4'
    end
    if not set -q tide_gcloud_icon
        set -U tide_gcloud_icon '󰊭'
    end
    if not set -q tide_git_bg_color
        set -U tide_git_bg_color 'normal'
    end
    if not set -q tide_git_bg_color_unstable
        set -U tide_git_bg_color_unstable 'normal'
    end
    if not set -q tide_git_bg_color_urgent
        set -U tide_git_bg_color_urgent 'normal'
    end
    if not set -q tide_git_color_branch
        set -U tide_git_color_branch '5FD700'
    end
    if not set -q tide_git_color_conflicted
        set -U tide_git_color_conflicted 'FF0000'
    end
    if not set -q tide_git_color_dirty
        set -U tide_git_color_dirty 'D7AF00'
    end
    if not set -q tide_git_color_operation
        set -U tide_git_color_operation 'FF0000'
    end
    if not set -q tide_git_color_staged
        set -U tide_git_color_staged 'D7AF00'
    end
    if not set -q tide_git_color_stash
        set -U tide_git_color_stash '5FD700'
    end
    if not set -q tide_git_color_untracked
        set -U tide_git_color_untracked '00AFFF'
    end
    if not set -q tide_git_color_upstream
        set -U tide_git_color_upstream '5FD700'
    end
    if not set -q tide_git_icon
        set -U tide_git_icon ''
    end
    if not set -q tide_git_truncation_length
        set -U tide_git_truncation_length '24'
    end
    if not set -q tide_git_truncation_strategy
        set -U tide_git_truncation_strategy ''
    end
    if not set -q tide_go_bg_color
        set -U tide_go_bg_color 'normal'
    end
    if not set -q tide_go_color
        set -U tide_go_color '00ACD7'
    end
    if not set -q tide_go_icon
        set -U tide_go_icon ''
    end
    if not set -q tide_java_bg_color
        set -U tide_java_bg_color 'normal'
    end
    if not set -q tide_java_color
        set -U tide_java_color 'ED8B00'
    end
    if not set -q tide_java_icon
        set -U tide_java_icon ''
    end
    if not set -q tide_jobs_bg_color
        set -U tide_jobs_bg_color 'normal'
    end
    if not set -q tide_jobs_color
        set -U tide_jobs_color '5FAF00'
    end
    if not set -q tide_jobs_icon
        set -U tide_jobs_icon ''
    end
    if not set -q tide_jobs_number_threshold
        set -U tide_jobs_number_threshold '1000'
    end
    if not set -q tide_kubectl_bg_color
        set -U tide_kubectl_bg_color 'normal'
    end
    if not set -q tide_kubectl_color
        set -U tide_kubectl_color '326CE5'
    end
    if not set -q tide_kubectl_icon
        set -U tide_kubectl_icon '󱃾'
    end
    if not set -q tide_left_prompt_frame_enabled
        set -U tide_left_prompt_frame_enabled 'false'
    end
    if not set -q tide_left_prompt_items
        set -U tide_left_prompt_items 'pwd' 'git' 'character'
    end
    if not set -q tide_left_prompt_prefix
        set -U tide_left_prompt_prefix ''
    end
    if not set -q tide_left_prompt_separator_diff_color
        set -U tide_left_prompt_separator_diff_color ' '
    end
    if not set -q tide_left_prompt_separator_same_color
        set -U tide_left_prompt_separator_same_color ' '
    end
    if not set -q tide_left_prompt_suffix
        set -U tide_left_prompt_suffix ''
    end
    if not set -q tide_nix_shell_bg_color
        set -U tide_nix_shell_bg_color 'normal'
    end
    if not set -q tide_nix_shell_color
        set -U tide_nix_shell_color '7EBAE4'
    end
    if not set -q tide_nix_shell_icon
        set -U tide_nix_shell_icon ''
    end
    if not set -q tide_node_bg_color
        set -U tide_node_bg_color 'normal'
    end
    if not set -q tide_node_color
        set -U tide_node_color '44883E'
    end
    if not set -q tide_node_icon
        set -U tide_node_icon ''
    end
    if not set -q tide_os_bg_color
        set -U tide_os_bg_color 'normal'
    end
    if not set -q tide_os_color
        set -U tide_os_color 'normal'
    end
    if not set -q tide_os_icon
        set -U tide_os_icon ''
    end
    if not set -q tide_php_bg_color
        set -U tide_php_bg_color 'normal'
    end
    if not set -q tide_php_color
        set -U tide_php_color '617CBE'
    end
    if not set -q tide_php_icon
        set -U tide_php_icon ''
    end
    if not set -q tide_private_mode_bg_color
        set -U tide_private_mode_bg_color 'normal'
    end
    if not set -q tide_private_mode_color
        set -U tide_private_mode_color 'FFFFFF'
    end
    if not set -q tide_private_mode_icon
        set -U tide_private_mode_icon '󰗹'
    end
    if not set -q tide_prompt_add_newline_before
        set -U tide_prompt_add_newline_before 'false'
    end
    if not set -q tide_prompt_color_frame_and_connection
        set -U tide_prompt_color_frame_and_connection '6C6C6C'
    end
    if not set -q tide_prompt_color_separator_same_color
        set -U tide_prompt_color_separator_same_color '949494'
    end
    if not set -q tide_prompt_icon_connection
        set -U tide_prompt_icon_connection ' '
    end
    if not set -q tide_prompt_min_cols
        set -U tide_prompt_min_cols '34'
    end
    if not set -q tide_prompt_pad_items
        set -U tide_prompt_pad_items 'false'
    end
    if not set -q tide_prompt_transient_enabled
        set -U tide_prompt_transient_enabled 'false'
    end
    if not set -q tide_pulumi_bg_color
        set -U tide_pulumi_bg_color 'normal'
    end
    if not set -q tide_pulumi_color
        set -U tide_pulumi_color 'F7BF2A'
    end
    if not set -q tide_pulumi_icon
        set -U tide_pulumi_icon ''
    end
    if not set -q tide_pwd_bg_color
        set -U tide_pwd_bg_color 'normal'
    end
    if not set -q tide_pwd_color_anchors
        set -U tide_pwd_color_anchors '00AFFF'
    end
    if not set -q tide_pwd_color_dirs
        set -U tide_pwd_color_dirs '0087AF'
    end
    if not set -q tide_pwd_color_truncated_dirs
        set -U tide_pwd_color_truncated_dirs '8787AF'
    end
    if not set -q tide_pwd_icon
        set -U tide_pwd_icon ''
    end
    if not set -q tide_pwd_icon_home
        set -U tide_pwd_icon_home ''
    end
    if not set -q tide_pwd_icon_unwritable
        set -U tide_pwd_icon_unwritable ''
    end
    if not set -q tide_pwd_markers
        set -U tide_pwd_markers '.bzr' '.citc' '.git' '.hg' '.node-version' '.python-version' '.ruby-version' '.shorten_folder_marker' '.svn' '.terraform' 'Cargo.toml' 'composer.json' 'CVS' 'go.mod' 'package.json' 'build.zig'
    end
    if not set -q tide_python_bg_color
        set -U tide_python_bg_color 'normal'
    end
    if not set -q tide_python_color
        set -U tide_python_color '00AFAF'
    end
    if not set -q tide_python_icon
        set -U tide_python_icon '󰌠'
    end
    if not set -q tide_right_prompt_frame_enabled
        set -U tide_right_prompt_frame_enabled 'false'
    end
    if not set -q tide_right_prompt_items
        set -U tide_right_prompt_items 'status' 'cmd_duration' 'context' 'jobs' 'direnv' 'node' 'python' 'rustc' 'java' 'php' 'pulumi' 'ruby' 'go' 'gcloud' 'kubectl' 'distrobox' 'toolbox' 'terraform' 'aws' 'nix_shell' 'crystal' 'elixir' 'zig'
    end
    if not set -q tide_right_prompt_prefix
        set -U tide_right_prompt_prefix ' '
    end
    if not set -q tide_right_prompt_separator_diff_color
        set -U tide_right_prompt_separator_diff_color ' '
    end
    if not set -q tide_right_prompt_separator_same_color
        set -U tide_right_prompt_separator_same_color ' '
    end
    if not set -q tide_right_prompt_suffix
        set -U tide_right_prompt_suffix ''
    end
    if not set -q tide_ruby_bg_color
        set -U tide_ruby_bg_color 'normal'
    end
    if not set -q tide_ruby_color
        set -U tide_ruby_color 'B31209'
    end
    if not set -q tide_ruby_icon
        set -U tide_ruby_icon ''
    end
    if not set -q tide_rustc_bg_color
        set -U tide_rustc_bg_color 'normal'
    end
    if not set -q tide_rustc_color
        set -U tide_rustc_color 'F74C00'
    end
    if not set -q tide_rustc_icon
        set -U tide_rustc_icon ''
    end
    if not set -q tide_shlvl_bg_color
        set -U tide_shlvl_bg_color 'normal'
    end
    if not set -q tide_shlvl_color
        set -U tide_shlvl_color 'd78700'
    end
    if not set -q tide_shlvl_icon
        set -U tide_shlvl_icon ''
    end
    if not set -q tide_shlvl_threshold
        set -U tide_shlvl_threshold '1'
    end
    if not set -q tide_status_bg_color
        set -U tide_status_bg_color 'normal'
    end
    if not set -q tide_status_bg_color_failure
        set -U tide_status_bg_color_failure 'normal'
    end
    if not set -q tide_status_color
        set -U tide_status_color '5FAF00'
    end
    if not set -q tide_status_color_failure
        set -U tide_status_color_failure 'D70000'
    end
    if not set -q tide_status_icon
        set -U tide_status_icon '✔'
    end
    if not set -q tide_status_icon_failure
        set -U tide_status_icon_failure '✘'
    end
    if not set -q tide_terraform_bg_color
        set -U tide_terraform_bg_color 'normal'
    end
    if not set -q tide_terraform_color
        set -U tide_terraform_color '844FBA'
    end
    if not set -q tide_terraform_icon
        set -U tide_terraform_icon '󱁢'
    end
    if not set -q tide_time_bg_color
        set -U tide_time_bg_color 'normal'
    end
    if not set -q tide_time_color
        set -U tide_time_color '5F8787'
    end
    if not set -q tide_time_format
        set -U tide_time_format ''
    end
    if not set -q tide_toolbox_bg_color
        set -U tide_toolbox_bg_color 'normal'
    end
    if not set -q tide_toolbox_color
        set -U tide_toolbox_color '613583'
    end
    if not set -q tide_toolbox_icon
        set -U tide_toolbox_icon ''
    end
    if not set -q tide_vi_mode_bg_color_default
        set -U tide_vi_mode_bg_color_default 'normal'
    end
    if not set -q tide_vi_mode_bg_color_insert
        set -U tide_vi_mode_bg_color_insert 'normal'
    end
    if not set -q tide_vi_mode_bg_color_replace
        set -U tide_vi_mode_bg_color_replace 'normal'
    end
    if not set -q tide_vi_mode_bg_color_visual
        set -U tide_vi_mode_bg_color_visual 'normal'
    end
    if not set -q tide_vi_mode_color_default
        set -U tide_vi_mode_color_default '949494'
    end
    if not set -q tide_vi_mode_color_insert
        set -U tide_vi_mode_color_insert '87AFAF'
    end
    if not set -q tide_vi_mode_color_replace
        set -U tide_vi_mode_color_replace '87AF87'
    end
    if not set -q tide_vi_mode_color_visual
        set -U tide_vi_mode_color_visual 'FF8700'
    end
    if not set -q tide_vi_mode_icon_default
        set -U tide_vi_mode_icon_default 'D'
    end
    if not set -q tide_vi_mode_icon_insert
        set -U tide_vi_mode_icon_insert 'I'
    end
    if not set -q tide_vi_mode_icon_replace
        set -U tide_vi_mode_icon_replace 'R'
    end
    if not set -q tide_vi_mode_icon_visual
        set -U tide_vi_mode_icon_visual 'V'
    end
    if not set -q tide_zig_bg_color
        set -U tide_zig_bg_color 'normal'
    end
    if not set -q tide_zig_color
        set -U tide_zig_color 'F7A41D'
    end
    if not set -q tide_zig_icon
        set -U tide_zig_icon ''
    end
end
if status is-interactive
    __kova_tide_defaults
end
