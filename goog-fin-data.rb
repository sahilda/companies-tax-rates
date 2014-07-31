require 'nokogiri'
require 'restclient'
require 'csv'
require 'json'

def get_financials(company)
	ticker = company[0]
	exchange = company[1]['exchange']
	page = Nokogiri::HTML(RestClient.get("https://www.google.com/finance?q=#{ticker.upcase}%3A#{ticker}&fstype=ii&ei=gSvXU6iWEIGiigK-nIHgCw"))

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
			rev[idx].to_f == 0 ? effective_tax_rate << 'NA' : effective_tax_rate << tax_paid[idx] / rev[idx].to_f * 100
		end
	end

	data = [header, rev, profit, tax_paid, effective_tax_rate]
end

def convert_to_hash(data)
	result = {}
	result['units'] = data[0][0]
	data[0].size.times do | idx |
		unless idx == 0
			year = data[0][idx][/(\d)+/]
			result[year] = {}
			result[year]['date'] = data[0][idx]
			result[year]['revenue'] = data[1][idx]
			result[year]['profit'] = data[2][idx]
			result[year]['taxes'] = data[3][idx]
			result[year]['etr'] = data[4][idx]
		end
	end
	result
end

def make_dataset(stocks, file)
	json = stocks
	i = 0

	json.each do | company |
		i += 1 
		begin
			data = get_financials(company)
			json[company[0]] = convert_to_hash(data).merge(json[company[0]])
		rescue
		end
		break if i == 5
	end

	File.open("data/#{file}-stock-data.json",'w') do | f |
		f.write(json.to_json)
	end
end

def companies(exchange)
	result = {}
	csv = CSV.foreach("data/#{exchange}.csv", :headers => TRUE) do | row |
	  result[row['Symbol']] = {}
	  result[row['Symbol']]['name'] = row['Name']
	  result[row['Symbol']]['market_cap'] = row['MarketCap']
	  result[row['Symbol']]['ipo_year'] = row['IPOyear']
	  result[row['Symbol']]['sector'] = row['sector']
	  result[row['Symbol']]['industry'] = row['industry']
	  result[row['Symbol']]['exchange'] = exchange
	  result[row['Symbol']]['exchange2'] = 'amex' if exchange == 'nysemkt'
	end
	result
end

def main
	nasdaq = companies('nasdaq')
	amex = companies('nysemkt')
	nyse = companies('nyse')

	make_dataset(nyse, 'nyse')
	make_dataset(amex, 'nysemkt')
	make_dataset(nasdaq, 'nasdaq')
end

main