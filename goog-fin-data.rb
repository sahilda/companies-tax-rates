require 'nokogiri'
require 'restclient'
require 'csv'
require 'json'

def get_financials(ticker)
	page = Nokogiri::HTML(RestClient.get("https://www.google.com/finance?q=NASDAQ%3A#{ticker}&fstype=ii&ei=gSvXU6iWEIGiigK-nIHgCw"))

	header_info = page.css("div,id-incannualdiv").css("table").css("thead")[1]
	rev_info = page.css("div,id-incannualdiv").css("table").css("tbody").css("tbody")[1].css("tr")[2]
	profit_info = page.css("div,id-incannualdiv").css("table").css("tbody").css("tbody")[1].css("tr")[4]
	income_before_tax_info = page.css("div,id-incannualdiv").css("table").css("tbody").css("tbody")[1].css("tr")[16]
	income_after_tax_info = page.css("div,id-incannualdiv").css("table").css("tbody").css("tbody")[1].css("tr")[17]

	def convert_numbers(array)
		result = []
		array.size.times do | idx |
			if idx == 0
				result << array[idx]
			else
				result << array[idx].gsub(',','').to_f
			end
		end
		result
	end

	def convert_dates(array)
		result = []
		array.size.times do | idx |
			if idx == 0
				result << array[idx].split(' ')[1]
			else
				result << array[idx][/(\d)+-(\d)+-(\d)+/]
			end
		end
		result
	end

	def get_data(info, type)
		result = []
		info.css(type).each do | t |
			result << t.text.strip
		end
		result
	end

	header = convert_dates(get_data(header_info, 'th'))
	rev = convert_numbers(get_data(rev_info, 'td'))
	profit = convert_numbers(get_data(profit_info, 'td'))
	income_before_tax = convert_numbers(get_data(income_before_tax_info, 'td'))
	income_after_tax = convert_numbers(get_data(income_after_tax_info, 'td'))
	tax_paid = ['Taxes Paid']
	effective_tax_rate = ['Effective Tax Rate']

	income_before_tax.size.times do | idx |
		unless idx == 0
			tax_paid << income_before_tax[idx].to_f - income_after_tax[idx].to_f
			effective_tax_rate << tax_paid[idx] / rev[idx].to_f * 100
		end
	end

	data = [header, rev, profit, tax_paid, effective_tax_rate]
end

def convert_to_hash(data)
	result = {}
	result['units'] = data[0][0]
	data[0].size.times do | idx |
		unless idx == 0
			result["year#{idx}"] = {}
			result["year#{idx}"]['date'] = data[0][idx]
			result["year#{idx}"]['revenue'] = data[1][idx]
			result["year#{idx}"]['profit'] = data[2][idx]
			result["year#{idx}"]['taxes'] = data[3][idx]
			result["year#{idx}"]['etr'] = data[4][idx]
		end
	end
	result
end

def make_dataset(companies)
	json = {}
	companies.each do | comp |
		data = get_financials(comp)
		json[comp] = convert_to_hash(data) 
	end

	File.open('stock-data.json','w') do | f |
		f.write(json.to_json)
	end
end

companies = ['XOOM','GOOGL','AAPL']
make_dataset(companies)