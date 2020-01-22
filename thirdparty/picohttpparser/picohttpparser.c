#include "src/picohttpparser.c"

// date
#include <time.h>

const char* get_date() {
	time_t t;
	struct tm tm;
	static const char *days[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
	static const char *months[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
	static char date[30] = "Thu, 01 Jan 1970 00:00:00 GMT";

	time(&t);
	#ifdef __WINDOWS__
		gmtime(&t, &tm);
	#else
		gmtime_r(&t, &tm);
	#endif
	strftime(date, 30, "---, %d --- %Y %H:%M:%S GMT", &tm);
	memcpy(date, days[tm.tm_wday], 3);
	memcpy(date + 8, months[tm.tm_mon], 3);

	return date;
}
