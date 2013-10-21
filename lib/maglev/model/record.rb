module Maglev
  module Record
    def delegate
      self
    end

    def record_class
      self
    end

    # move to utils
    def underscore(camel_cased_word)
      word = camel_cased_word.to_s.dup
      word.gsub!('::', '/')
      word.gsub!(/(?:([A-Za-z\d])|^)(#{acronym_regex})(?=\b|[^a-z])/) { "#{$1}#{$1 && '_'}#{$2.downcase}" }
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
    end

    def acronym_regex
      /(?=a)b/
    end

    def record_class_underscore
      underscore(record_class.name)
    end

    def create_model(json)
      record_class.new(json)
    end

    def remote_find(id, params = {}, &block)
      get(member_path.format(params.merge(id: id), self.delegate)) do |response, json|
        if response.ok?
          attributes = json[record_class_underscore]
          puts record_class_underscore
          puts attributes
          obj = create_model(attributes)
          request_block_call(block, obj, response)
        else
          request_block_call(block, nil, response)
        end
      end
    end

    def remote_find_all(params = {}, &block)
      url = collection_path.format(params, self.delegate)
      get(url) do |response, json|
        if response.ok?
          objs = []
          arr_rep = nil
          case json
          when Array
            arr_rep = json
          when Hash
            arr_rep = json[record_class_underscore.pluralize]
            #[self.record_class.inspect.pluralize.to_sym, self.collection_options[:json_path]].collect do |key_path|
            #  puts key_path
            #  if json.include? key_path
            #    arr_rep = json[key_path]
            #  end
            #end
          else
            # the returned data was something else
            # ie a string, number
            request_block_call(block, nil, response)
            return
          end
          arr_rep && arr_rep.each { |one_obj_hash|
            objs << create_model(one_obj_hash)
          }
          request_block_call(block, objs, response)
        else
          request_block_call(block, nil, response)
        end
      end
    end

    # Enables the find
    private
    def request_block_call(block, default_arg, extra_arg)
      raise Maglev::Error::BlockRequiredError, "No block given" if !block
      case block.arity
      when 1
        block.call default_arg
      when 2
        block.call default_arg, extra_arg
      else
        raise Maglev::Error::BlockArgumentsError, "Incorrect block arguments; need 1 or 2"
      end
    end
  end

  module RecordInstance
    # EX
    # a_model.destroy do |response, json|
    #   if json[:success]
    #     p "success!"
    #   end
    # end
    def remote_destroy(&block)
      delete(self.member_path) do |response, json|
        if block
          block.call response, json
        end
      end
    end
  end
end
