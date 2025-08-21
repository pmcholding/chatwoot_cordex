module CustomExceptions::ScheduledMessage
  class InvalidScheduleTime < CustomExceptions::Base
    def message
      'Scheduled time must be in the future'
    end
  end

  class ScheduleLimitExceeded < CustomExceptions::Base
    def message
      'Maximum number of scheduled messages exceeded for this conversation'
    end
  end

  class SchedulePermissionDenied < CustomExceptions::Base
    def message
      'User does not have permission to schedule messages'
    end
  end
end
