/* CrackAgent.cc
 *
 * An agent for reading the crack configuration file.
 *
 * Authors: Jiri Suchomel <jsuchome@suse.cz>
 *
 * $Id$
 */

#include "CrackAgent.h"

/**
 * Constructor
 */
CrackAgent::CrackAgent() : SCRAgent()
{
}

/**
 * Destructor
 */
CrackAgent::~CrackAgent()
{
}

/**
 * Dir
 */
YCPList CrackAgent::Dir(const YCPPath& path)
{
    y2error("Wrong path '%s' in Read().", path->toString().c_str());
    return YCPNull();
}

/**
 * Read
 */
YCPValue CrackAgent::Read(const YCPPath &path, const YCPValue& arg,
	const YCPValue& opt)
{
    y2error("Wrong path '%s' in Read().", path->toString().c_str());
    return YCPVoid();
}

/**
 * Write
 */
YCPBoolean CrackAgent::Write(const YCPPath &path, const YCPValue& value,
    const YCPValue& arg)
{
    y2error("Wrong path '%s' in Write().", path->toString().c_str());
    return YCPBoolean(false);
}

/**
 * Execute
 */
YCPValue CrackAgent::Execute(const YCPPath &path, const YCPValue& value,
	   const YCPValue& arg)
{
    char *pass = (char *) value->toString().c_str();
    const char *dictpath = "/usr/lib/cracklib_dict";
    if (!arg.isNull())
    {
	dictpath = arg->asString()->value().c_str();
    }

    char *out = (char*) FascistCheck (pass, (char *) dictpath);
    if (out) {
	return YCPString (out);
    }
    else {
	return YCPString ("");
    }
}

/**
 * otherCommand
 */
YCPValue CrackAgent::otherCommand(const YCPTerm& term)
{
    string sym = term->name();

    if (sym == "CrackAgent") {
        /* Your initialization */
        return YCPVoid();
    }

    return YCPNull();
}
