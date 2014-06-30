module Que
  module Adapters
    class ActiveRecord < Base
      def checkout
        checkout_activerecord_adapter { |conn| yield conn.raw_connection }
      end

      def wake_worker_after_commit
        # Works with ActiveRecord 3.2 and 4 (possibly earlier, didn't check)
        if in_transaction?
          checkout_activerecord_adapter { |adapter| adapter.add_transaction_record(CommittedCallback.new) }
        else
          Que.wake!
        end
      end

      class CommittedCallback
        def has_transactional_callbacks?
          true
        end

        def committed!
          Que.wake!
        end
      end

      private

      def checkout_activerecord_adapter(&block)
        Timeout.timeout(1) do
          begin
            ::ActiveRecord::Base.connection_pool.with_connection(&block)
          rescue ::ActiveRecord::ConnectionNotEstablished => e
            puts "couldn't connect to db, retrying..."
            sleep 0.1
            retry
          end
        end
      end
    end
  end
end
