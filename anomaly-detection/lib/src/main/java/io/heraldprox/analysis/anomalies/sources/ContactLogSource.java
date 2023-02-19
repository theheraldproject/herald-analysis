//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies.sources;

import io.heraldprox.analysis.anomalies.Event;
import io.heraldprox.analysis.anomalies.EventType;
import io.heraldprox.analysis.anomalies.EventGroupSummary;
import io.heraldprox.analysis.anomalies.EventSource;
import io.heraldprox.analysis.anomalies.EventList;
import io.heraldprox.analysis.anomalies.EventPointer;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Locale;
import java.util.TimeZone;
import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.io.File;
import java.util.SortedSet;
import java.util.TreeSet;
import java.util.Hashtable;
import java.util.Date;

public class ContactLogSource implements EventSource {
    private final static SimpleDateFormat dateFormatter = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.UK);
    static {
        dateFormatter.setTimeZone(TimeZone.getTimeZone("UTC"));
    }

    protected File file;
    protected boolean initialised = false;

    // variables that depend upon initialise() being called:-
    protected EventGroupSummary summary = new EventGroupSummary(new TreeSet<EventType>(),0);
    protected EventList events = new EventList();
    protected int lastIndex = 0;

    protected BufferedReader lineReader = null;
    protected int lastLineRead = 0;
    protected String lastLine = "";

    protected int dateColumn = 0;
    protected int sensorColumn = 0;
    protected int idColumn = 0;
    protected int detectColumn = 0;
    protected int readColumn = 0;
    protected int measureColumn = 0;
    protected int shareColumn = 0;
    protected int visitColumn = 0;
    protected int isHeraldColumn = 0;
    protected int deletedColumn = 0;
    protected int dataColumn = 0;

    public ContactLogSource(File contactFile) {
        file = contactFile;
    }

    protected void initialise() {
        if (initialised) {
            return;
        }
        try {
            BufferedReader reader = new BufferedReader(new FileReader(file));
            // Read header line
            String header = reader.readLine();
            String[] headerElements = header.split("[,]",-1);
            Hashtable<ContactLogColumn,Integer> columns = new Hashtable<ContactLogColumn,Integer>();
            for (int i = 0;i < headerElements.length;++i) {
                String h = headerElements[i];
                if ("time".equals(h)) {
                    columns.put(ContactLogColumn.DateTime,i);
                } else if ("sensor".equals(h)) {
                    columns.put(ContactLogColumn.Sensor,i);
                } else if ("id".equals(h)) {
                    columns.put(ContactLogColumn.Id,i);
                } else if ("detect".equals(h)) {
                    columns.put(ContactLogColumn.Detect,i);
                } else if ("read".equals(h)) {
                    columns.put(ContactLogColumn.Read,i);
                } else if ("measure".equals(h)) {
                    columns.put(ContactLogColumn.Measure,i);
                } else if ("share".equals(h)) {
                    columns.put(ContactLogColumn.Share,i);
                } else if ("visit".equals(h)) {
                    columns.put(ContactLogColumn.Visit,i);
                } else if ("detectHerald".equals(h)) {
                    columns.put(ContactLogColumn.DetectHerald,i);
                } else if ("delete".equals(h)) {
                    columns.put(ContactLogColumn.Delete,i);
                } else if ("data".equals(h)) {
                    columns.put(ContactLogColumn.Data,i);
                }
            }

            long lineCount = 0;
            SortedSet<EventType> types = new TreeSet<EventType>();

            Integer dateColumnInt = columns.get(ContactLogColumn.DateTime);
            Integer sensorColumnInt = columns.get(ContactLogColumn.Sensor);
            Integer idColumnInt = columns.get(ContactLogColumn.Id);
            Integer detectColumnInt = columns.get(ContactLogColumn.Detect);
            Integer readColumnInt = columns.get(ContactLogColumn.Read);
            Integer measureColumnInt = columns.get(ContactLogColumn.Measure);
            Integer shareColumnInt = columns.get(ContactLogColumn.Share);
            Integer visitColumnInt = columns.get(ContactLogColumn.Visit);
            Integer isHeraldColumnInt = columns.get(ContactLogColumn.DetectHerald);
            Integer deletedColumnInt = columns.get(ContactLogColumn.Delete);
            Integer dataColumnInt = columns.get(ContactLogColumn.Data);

            if (
                null != dateColumnInt &&
                null != sensorColumnInt &&
                null != idColumnInt &&
                null != detectColumnInt &&
                null != readColumnInt &&
                null != measureColumnInt &&
                null != shareColumnInt &&
                null != visitColumnInt &&
                null != isHeraldColumnInt &&
                null != deletedColumnInt &&
                null != dataColumnInt
            ) {
                dateColumn = dateColumnInt.intValue();
                sensorColumn = sensorColumnInt.intValue();
                idColumn = idColumnInt.intValue();
                detectColumn = detectColumnInt.intValue();
                readColumn = readColumnInt.intValue();
                measureColumn = measureColumnInt.intValue();
                shareColumn = shareColumnInt.intValue();
                visitColumn = visitColumnInt.intValue();
                isHeraldColumn = isHeraldColumnInt.intValue();
                deletedColumn = deletedColumnInt.intValue();
                dataColumn = dataColumnInt.intValue();

                // Keep these commented out so we're flexible in future
                // if (1 != sensorColumn) {
                //     throw new Error("Sensor Column index should not be zero");
                // }
                // if (2 != idColumn) {
                //     throw new Error("ID Column index should not be zero");
                // }
                // if (4 != readColumn) {
                //     throw new Error("Read Column index should not be zero");
                // }
                // if (5 != measureColumn) {
                //     throw new Error("Measure Column index should not be zero");
                // }
                // if (8 != isHeraldColumn) {
                //     throw new Error("Herald Column index should not be zero");
                // }
                // if (10 != dataColumn) {
                //     throw new Error("Data Column index should not be zero");
                // }
                
                // Read each content line
                // final String blank = "";
                final String one = "1";
                final String two = "2";
                final String three = "3";
                final String four = "4";
                final String five = "5";
                final String six = "6";
                final String seven = "7";
                String line;
                while (null != (line = reader.readLine())) {
                    ++lineCount;
                    String[] elements = line.split(",",-1); // include empty values
                    if (elements.length < 9) {
                        continue;
                    }

                    // Extract common event fields
                    Date date = new Date();
                    try {
                        date = dateFormatter.parse(elements[dateColumn]);
                    } catch (ParseException pe) {
                        pe.printStackTrace(System.err);
                    }

                    // extract event
                    // if (null != elements[detectColumn] && !blank.equals(elements[detectColumn])) {
                    if (one.equals(elements[detectColumn])) {
                        types.add(EventType.ContactDetected);
                        events.add(new Event(
                            date,
                            EventType.ContactDetected,
                            new EventPointer(
                                this,
                                lineCount, // not the physical line in a csv file, but the event count
                                lineCount
                            )
                        ));
                    // } else if (null != elements[readColumn] && !blank.equals(elements[readColumn])) {
                    } else if (two.equals(elements[readColumn])) {
                        types.add(EventType.ContactRead);
                        events.add(new Event(
                            date,
                            EventType.ContactRead,
                            new EventPointer(
                                this,
                                lineCount, // not the physical line in a csv file, but the event count
                                lineCount
                            )
                        ));
                    // } else if (null != elements[measureColumn] && !blank.equals(elements[measureColumn])) {
                    } else if (three.equals(elements[measureColumn])) {
                        types.add(EventType.ContactMeasure);
                        events.add(new Event(
                            date,
                            EventType.ContactMeasure,
                            new EventPointer(
                                this,
                                lineCount, // not the physical line in a csv file, but the event count
                                lineCount
                            )
                        ));
                    // } else if (null != elements[shareColumn] && !blank.equals(elements[shareColumn])) {
                    } else if (four.equals(elements[shareColumn])) {
                        types.add(EventType.ContactShare);
                        events.add(new Event(
                            date,
                            EventType.ContactShare,
                            new EventPointer(
                                this,
                                lineCount, // not the physical line in a csv file, but the event count
                                lineCount
                            )
                        ));
                    // } else if (null != elements[visitColumn] && !blank.equals(elements[visitColumn])) {
                    } else if (five.equals(elements[visitColumn])) {
                        types.add(EventType.ContactVisit);
                        events.add(new Event(
                            date,
                            EventType.ContactVisit,
                            new EventPointer(
                                this,
                                lineCount, // not the physical line in a csv file, but the event count
                                lineCount
                            )
                        ));
                    // } else if (null != elements[isHeraldColumn] && !blank.equals(elements[isHeraldColumn])) {
                    } else if (six.equals(elements[isHeraldColumn])) {
                        types.add(EventType.ContactIsHerald);
                        events.add(new Event(
                            date,
                            EventType.ContactIsHerald,
                            new EventPointer(
                                this,
                                lineCount, // not the physical line in a csv file, but the event count
                                lineCount
                            )
                        ));
                    // } else if (null != elements[deletedColumn] && !blank.equals(elements[deletedColumn])) {
                    } else if (seven.equals(elements[deletedColumn])) {
                        types.add(EventType.ContactDeleted);
                        events.add(new Event(
                            date,
                            EventType.ContactDeleted,
                            new EventPointer(
                                this,
                                lineCount, // not the physical line in a csv file, but the event count
                                lineCount
                            )
                        ));
                    }
                }
            } // format check
            reader.close();
            summary = new EventGroupSummary(types, lineCount);
        } catch (IOException ioe) {
            ioe.printStackTrace(System.err);
        }
    }

    @Override
    public EventGroupSummary summarise() {
        initialise();
        return summary;
    }

    @Override
    public boolean hasEvent() {
        return 0 != events.size() && lastIndex < events.size();
    }

    @Override
    public Event first() {
        lastIndex = 0;
        if (!hasEvent()) {
            return null;
        }
        return events.atIndex(lastIndex);
    }

    protected Event findNextByType(final EventType type) {
        Event found = events.atIndex(lastIndex);
        boolean matches = false;
        while (!matches && null != found && lastIndex < events.size()) {
            matches = (found.type() == type);
            if (!matches) {
                lastIndex++;
                found = events.atIndex(lastIndex);
            }
        }
        if (lastIndex > events.size()) {
            lastIndex = events.size();
        }
        return found;
    }

    @Override
    public Event firstByType(EventType type) {
        lastIndex = 0;
        return findNextByType(type);
    }

    @Override
    public Event next() {
        lastIndex++;

        Event found = events.atIndex(lastIndex);
        if (lastIndex > events.size()) {
            lastIndex = events.size();
        }
        return found;
    }

    @Override
    public Event nextByType(EventType type) {
        lastIndex++;
        return findNextByType(type);
    }

    @Override
    public String text(long lineNumber) {
        try {
            final String blank = "";
            if (null != lineReader) {
                if (lineNumber > lastLineRead) {
                    // close and reset
                    lineReader.close();
                    lineReader = null;
                }
            }
            if (null == lineReader) {
                lineReader = new BufferedReader(new FileReader(file));
                lastLineRead = 1;
                lineReader.readLine(); // header line, index 0
                lastLine = lineReader.readLine();
            }
            // our indexes are EVENT numbers, so header is index 0, first data line is line/event 1
            // if (lastLineRead == lineNumber) {
            //     return lastLine;
            // }
            while (lastLineRead < lineNumber && null != lastLine) {
                lastLine = lineReader.readLine();
                lastLineRead++;
            }
            // if (lastLineRead != lineNumber) {
            //     // end of file before lineNumber reached
            //     return "";
            // }
            // Finally we have the right line
            // Now process it to only return event data outside of the event description (I.e. only Source,Address,Data)
            if (null != lastLine && !blank.equals(lastLine)) {
                String[] lastSplit = lastLine.split("[,]",-1); // Returns empty values with -1
                if (lastSplit.length < 11) {
                    throw new Error("Generated Source lastLine should have three elements: " + lastLine);
                }
                return lastSplit[sensorColumn] + "," + lastSplit[idColumn] + "," + lastSplit[dataColumn];
            }
        } catch (IOException ioe) {
            ioe.printStackTrace();
        }
        return "";
    }
    
    enum ContactLogColumn {
        DateTime,
        Sensor,
        Id,
        Detect,
        Read,
        Measure,
        Share,
        Visit,
        DetectHerald,
        Delete,
        Data,
    }
}
