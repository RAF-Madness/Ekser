"""
● Port na kojem će čvor da sluša. (short)
● IP adresa i port bootstrap čvora - odeljak 3.1. (string i short)
● Slaba granica otkaza - odeljak 3.2. (int)
● Jaka granica otkaza - odeljak 3.2. (int)
● Skup predefinisanih poslova.
defmodule Configuration do
    defstruct [:port, :bootstrap_ip, :bootstrap_port, :watchdog_timer, :failure_timer, job_list: []]

    def new() do
		%Configuration{}
	end
	
	def increment_age(person) do
		%Person{person | age: person.age + 1}
	end
	
	def babify(person) do
		%Person{person | age: 1, stage: :baby}
	end
	
	def can_retire?(person, retirement_age) do
		person.age >= retirement_age
	end	
end

defmodule Starter do
    config_fields = ["port", "bootstrap-ip", "bootstrap-port", "low-end-tolerance", "high-end-tolerance"]
    job_fields = ["N", "P", "W", "H", "A"]

    def tokenize_line(line) do
        String.split()
    end

    def read_field(line) do
        kubernetes
    end
    
    def read_config(config_file) do

    end
end