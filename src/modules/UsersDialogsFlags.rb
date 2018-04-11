module Yast
  # TODO: when not called from perl, it can be common ruby lib
  class  UsersDialogsFlagsClass < Module
    def assign_start_dialog(name)
      @start_dialog = name
    end

    # define dialog which should be used as first one, can be modified with {start_dialog=}
    def start_dialog
      # summary is starting dialog for installation
      @start_dialog ||= "summary"
    end

    def assign_use_next_time(value)
      @use_next_time = value
    end

    def use_next_time
      @use_next_time = false if @use_next_time.nil?
      @use_next_time
    end

    publish function: :assign_start_dialog, type: "void (string)"
    publish function: :start_dialog, type: "string ()"
    publish function: :assign_use_next_time, type: "void (boolean)"
    publish function: :use_next_time, type: "boolean ()"
  end

  UsersDialogsFlags = UsersDialogsFlagsClass.new
end
