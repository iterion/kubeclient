require 'kubeclient/version'
require 'json'
require 'rest-client'
require 'active_support/inflector'
require 'kubeclient/pod'
require 'kubeclient/node'
require 'kubeclient/service'
require 'kubeclient/replication_controller'
require 'kubeclient/entity_list'
require 'kubeclient/kube_exception'


module Kubeclient
  class Client
   attr_reader :api_endpoint
   ENTITIES = %w(Pod Service ReplicationController Node)

    def initialize(api_endpoint,version)
      if !api_endpoint.end_with? "/"
         api_endpoint = api_endpoint + "/"
      end
      @api_endpoint = api_endpoint+version
    end

    private
    def rest_client
      #todo should a new one be created for every request?
      RestClient::Resource.new(@api_endpoint)
    end

    protected
    def create_entity(hash, entity, method_name)
      entity.classify.constantize.new(hash)
    end


    public

   ENTITIES.each do |entity|

     #get all entities of a type e.g. get_nodes, get_pods, etc.
     define_method("get_#{entity.underscore.pluralize}") do |labels=nil|
       #todo labels support
       #todo namespace support?
       begin
         response = rest_client[entity.pluralize.camelize(:lower)].get # nil, labels
       rescue  RestClient::Exception => e
         exception = KubeException.new(e.http_code, JSON.parse(e.response)['message'] )
         raise exception
       end
        result = JSON.parse(response)
        collection = EntityList.new(entity,result["resourceVersion"])
        result["items"].each { |item | collection.push(create_entity(item, entity, "underscore"))  }
        collection
     end

     #get a single entity of a specific type by id
     define_method("get_#{entity.underscore}") do |id|
       begin
         response = rest_client[entity.pluralize.camelize(:lower)+"/#{id}"].get
       rescue  RestClient::Exception => e
         exception = KubeException.new(e.http_code, JSON.parse(e.response)['message'] )
         raise exception
       end
         result = JSON.parse(response)
         create_entity(result, entity, "underscore")
     end

     define_method("delete_#{entity.underscore}") do |id|
       begin
         rest_client[entity.underscore.pluralize+"/" +id].delete
       rescue  RestClient::Exception => e
         exception = KubeException.new(e.http_code, JSON.parse(e.response)['message'] )
         raise exception
       end

     end

     define_method("create_#{entity.underscore}") do |entity_config|
       #to_hash should be called because of issue #9 in recursive open struct
       hash = entity_config.to_hash
       begin
         rest_client[entity.pluralize.camelize(:lower)].post(hash.to_json)
       rescue  RestClient::Exception => e
         exception = KubeException.new(e.http_code, JSON.parse(e.response)['message'] )
         raise exception
       end
     end

     define_method("update_#{entity.underscore}") do |entity_config|
       id = entity_config.id
       #to_hash should be called because of issue #9 in recursive open struct
       hash = entity_config.to_hash
       #temporary solution to delete id till this issue is solved: https://github.com/GoogleCloudPlatform/kubernetes/issues/3085
       hash.delete(:id)
       begin
         rest_client[entity.underscore.pluralize+"/#{id}"].put(hash.to_json)
       rescue  RestClient::Exception => e
         exception = KubeException.new(e.http_code, JSON.parse(e.response)['message'] )
         raise exception
       end
     end

   end

   public
   def get_all_entities
      result_hash = {}
      ENTITIES.each do |entity|
        # method call for get each entities
        # build hash of entity name to array of the entities
        method_name = "get_#{entity.underscore.pluralize}"
        key_name = entity.underscore
        result_hash[key_name] = send(method_name)
      end
     result_hash
    end
  end
end
