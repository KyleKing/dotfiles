#!/usr/bin/env ruby

require 'json'

def main
  puts JSON.pretty_generate(
    "title" => "@ Home Home Row Keys for Modifiers (using if_alone)",
    "maintainers" => ["eytanhanig"],
    # # Uncomment conditions to only apply modifications to internal apple keboards
    # "conditions" => [
    #   {
    #     "identifiers" => [
    #       {
    #         "is_built_in_keyboard" => true,
    #       },
    #       {
    #         "vendor_id" => 1452,
    #       },
    #     ],
    #     "type" => "device_if"
    #   }
    # ],
    "rules" => [
      {
        "description" => "Home Row (w/out CapsLock)\t⟶\t  [C]FnSAG ([Ctrl] Fn Shift Alt GUI)",
        "manipulators" => [
          # Left Hand
          generate_hold_modifier_only("a", "fn"),
          generate_hold_modifier_only("s", "left_shift"),
          generate_hold_modifier_only("d", "left_option"),
          generate_hold_modifier_only("f", "left_command"),
          # Right Hand
          generate_hold_modifier_only("j", "right_command"),
          generate_hold_modifier_only("k", "right_option"),
          generate_hold_modifier_only("l", "right_shift"),
          generate_hold_modifier_only("semicolon", "fn"),
          generate_hold_modifier_only("quote", "right_control"),
        ],
      },
      {
        "description" => "Home Row (w/out CapsLock)\t⟶\t  [Fn]CAGS ([Fn] Ctrl Alt GUI Shift)",
        "manipulators" => [
          # Left Hand
          generate_hold_modifier_only("a", "left_control"),
          generate_hold_modifier_only("s", "left_option"),
          generate_hold_modifier_only("d", "left_command"),
          generate_hold_modifier_only("f", "left_shift"),
          # Right Hand
          generate_hold_modifier_only("j", "right_shift"),
          generate_hold_modifier_only("k", "right_command"),
          generate_hold_modifier_only("l", "right_option"),
          generate_hold_modifier_only("semicolon", "right_control"),
          generate_hold_modifier_only("quote", "fn"),
        ],
      },
      {
        "description" => "Home Row (w/out CapsLock)\t⟶\t  [C]FnAGS ([Fn] Alt GUI Shift)",
        "manipulators" => [
          # Left Hand
          generate_hold_modifier_only("a", "fn"),
          generate_hold_modifier_only("s", "left_option"),
          generate_hold_modifier_only("d", "left_command"),
          generate_hold_modifier_only("f", "left_shift"),
          # Right Hand
          generate_hold_modifier_only("j", "right_shift"),
          generate_hold_modifier_only("k", "right_command"),
          generate_hold_modifier_only("l", "right_option"),
          generate_hold_modifier_only("semicolon", "fn"),
          generate_hold_modifier_only("quote", "right_control"),
        ],
      },
      {
        "description" => "Caps to Fn\t⟶\t  Forward Delete Only",
        "manipulators" => [
          generate_hold_modifier_and_if_alone("caps_lock", "fn", "delete_forward"),
        ],
      },
      {
        "description" => "Home Row (with CapsLock)\t⟶\t  CFnSAG (Ctrl Fn Shift Alt GUI)",
        "manipulators" => [
          # Left Hand
          generate_hold_modifier_and_if_alone("caps_lock", "left_control", "delete_forward"),
          generate_hold_modifier_only("a", "fn"),
          generate_hold_modifier_only("s", "left_shift"),
          generate_hold_modifier_only("d", "left_option"),
          generate_hold_modifier_only("f", "left_command"),
          # Right Hand
          generate_hold_modifier_only("j", "right_command"),
          generate_hold_modifier_only("k", "right_option"),
          generate_hold_modifier_only("l", "right_shift"),
          generate_hold_modifier_only("semicolon", "fn"),
          generate_hold_modifier_only("quote", "right_control"),
        ],
      },
      {
        "description" => "Home Row (with CapsLock)\t⟶\t  FnCAGS (Fn Ctrl Alt GUI Shift)",
        "manipulators" => [
          # Left Hand
          generate_hold_modifier_and_if_alone("caps_lock", "fn", "delete_forward"),
          generate_hold_modifier_only("a", "left_control"),
          generate_hold_modifier_only("s", "left_option"),
          generate_hold_modifier_only("d", "left_command"),
          generate_hold_modifier_only("f", "left_shift"),
          # Right Hand
          generate_hold_modifier_only("j", "right_shift"),
          generate_hold_modifier_only("k", "right_command"),
          generate_hold_modifier_only("l", "right_option"),
          generate_hold_modifier_only("semicolon", "right_control"),
          generate_hold_modifier_only("quote", "fn"),
        ],
      },
      {
        "description" => "Home Row (with CapsLock)\t⟶\t  CFnAGS (Ctrl Fn Alt GUI Shift)",
        "manipulators" => [
          # Left Hand
          generate_hold_modifier_and_if_alone("caps_lock", "left_control", "delete_forward"),
          generate_hold_modifier_only("a", "fn"),
          generate_hold_modifier_only("s", "left_option"),
          generate_hold_modifier_only("d", "left_command"),
          generate_hold_modifier_only("f", "left_shift"),
          # Right Hand
          generate_hold_modifier_only("j", "right_shift"),
          generate_hold_modifier_only("k", "right_command"),
          generate_hold_modifier_only("l", "right_option"),
          generate_hold_modifier_only("semicolon", "fn"),
          generate_hold_modifier_only("quote", "right_control"),
        ],
      },
    ],
  )
end

def generate_hold_modifier_and_if_alone(input, hold_modifier, alone_key_code)
  {
    # "parameters" => basic_parameters(),
    "parameters" => {
      'basic.to_if_alone_timeout_milliseconds' => 300,
      'basic.to_if_held_down_threshold_milliseconds' => 80,
      'basic.to_delayed_action_delay_milliseconds' => 80,
      # 'basic.simultaneous_threshold_milliseconds' => 300,
    },
    "description" => "Hold #{input.split(/ |\_/).map(&:capitalize).join(" ")} ⟶ #{hold_modifier.split(/ |\_/).map(&:capitalize).join(" ")}",
    "type" => "basic",
    "from" => {
      "key_code" => input,
      "modifiers" => { "optional" => ["any"] },
    },
    "to_delayed_action" => {
      "to_if_canceled" => [
        {
            "key_code" => alone_key_code
        }
      ]
    },
    "to_if_alone" => [
      {
        "key_code" => alone_key_code,
        "halt" => true
      }
    ],
    "to_if_held_down" => [
      {
        "key_code" => hold_modifier
      }
    ],
  }
end

def generate_hold_modifier_only(input, hold_modifier)
  generate_hold_modifier_and_if_alone(input, hold_modifier, input)
end

main()
