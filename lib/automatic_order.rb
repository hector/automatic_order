module HParra #:nodoc:
  module AutomaticOrder #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    # This module contains class methods
    module ClassMethods
      def automatic_order(opts={})
        set_variables(opts)
        before_create :assign_order
        before_destroy :unassign_order
        default_scope order query_order

        include HParra::AutomaticOrder::InstanceMethods
      end

      def order_column
        @order_column
      end

      def order_column=(value)
        @order_column = value
      end

      def parent_columns
        @parent_columns
      end

      def parent_columns=(value)
        @parent_columns = value
      end

      private

      def set_variables(opts={})
        @order_column = opts[:order_column].nil? ? "#{self.to_s.downcase}_order" : opts[:order_column].to_s
        if opts[:parent_columns].nil?
          @parent_columns = []
        elsif opts[:parent_columns].is_a? Array
          @parent_columns = opts[:parent_columns].map {|e| e.to_s}
        else
          @parent_columns = [opts[:parent_columns].to_s]
        end
      end

      def query_order
        order = @parent_columns.inject("") {|memo,obj| memo << "#{obj}, "}
        order << "#{@order_column} ASC"
      end

      # Nos reordena de nuevo la lista dejando un orden consistente
      # No preserva el orden existente
      # Usar solo en caso de que el orden haya quedado inconsistente
      def fix_order
        raise NotImplementedError, "metodo aun no implementado"
      end

    end

    # This module contains instance methods
    module InstanceMethods

      def inner_order
        send("#{self.class.order_column}")
      end

      def inner_order=(value)
        send("#{self.class.order_column}=",value)
      end

      def move_up
        move(1)
      end

      def move_down
        move(-1)
      end

      #Recoloca el panel desplazandolo +num+ posiciones
      # y deja el orden de todos los paneles coherente
      def move(num)
        old_order = inner_order
        new_order = old_order + num
        order_column = self.class.order_column
        parent_cond = parent_conditions
        parent_cond << " AND " unless parent_cond.blank?
        if num > 0
          max = max_order
          new_order = max if new_order > max
          self.class.update_all "#{order_column} = #{order_column} - 1",
                                "#{parent_cond}#{order_column} BETWEEN #{old_order+1} AND #{new_order}"
        else
          new_order = 1 if new_order < 1
          self.class.update_all "#{order_column} = #{order_column} + 1",
                                "#{parent_cond}#{order_column} BETWEEN #{new_order} AND #{old_order-1}"
        end

        update_attribute(order_column, new_order) unless self.frozen?
      end

      def max_order
        self.class.count(:all,:conditions=>parent_conditions)
      end

      protected

      # Asignamos el orden inicial
      def assign_order
        self.inner_order = max_order+1
      end

      # Reasignación del los ordenes para cuando borramos un elemento
      def unassign_order
        move(max_order)
      end

      def parent_conditions
        parent_columns = self.class.parent_columns
        conds = ""
        last = parent_columns.size-1
        for i in 0..last
          value = send(parent_columns[i])
          raise Exception, "Values for order must be set before 'save' is called" unless value
          conds << "#{parent_columns[i]}=#{value} "
          conds << "AND " unless i==last
        end
        return conds
      end
    end

  end
end
